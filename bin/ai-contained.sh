#!/bin/bash
set -euo pipefail

# Resolve the real script location through symlinks so docker-compose.yaml is
# found relative to the actual script, not wherever the (possibly-remote)
# symlink lives. BASH_SOURCE[0] handles PATH lookup (e.g. when invoked as bare
# `claude`); realpath follows the symlink chain (portable on Linux and macOS
# 12.3+).
readonly SCRIPT="$(realpath "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(dirname "$SCRIPT")"

# When invoked as `claude` (typically via symlink), behave as a drop-in
# replacement: workspace defaults to cwd, no first-arg requirement, all args
# pass through to claude.
CLAUDE_COMPATIBILITY=""
[[ "$(basename "$0")" == "claude" ]] && CLAUDE_COMPATIBILITY=1
readonly CLAUDE_COMPATIBILITY

# try to detect which docker-compose variant to use
if [[ -z "${COMPOSE_CMD:-}" ]]; then
    if command -v podman &>/dev/null && podman compose version &>/dev/null 2>&1; then
        COMPOSE_CMD="podman compose"
    elif command -v podman-compose &>/dev/null && podman-compose version &>/dev/null 2>&1; then
        COMPOSE_CMD="podman-compose"
    elif command -v docker &>/dev/null && docker compose version &>/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD=""
    fi
fi
readonly COMPOSE_CMD

usage() {
    echo "Usage: $0 <path>"
    echo "  path  Path to mount as /workspace (use '.' for current directory)"
    echo ""
    if [[ -n "${COMPOSE_CMD:-}" ]]; then
        echo "  Autodetected Compose Tool: ${COMPOSE_CMD}"
    else
        echo "  Error: no container compose tool found."
        echo "  Install Docker (https://docs.docker.com/get-docker/) or Podman (https://podman.io/getting-started/installation)."
    fi
    exit 1
}

if [[ -n "${CLAUDE_COMPATIBILITY}" ]]; then
    # claude compatibility mode: workspace = cwd, every arg passes through to claude.
    if [[ -z "${COMPOSE_CMD:-}" ]]; then
        usage
    fi
    readonly WORKSPACE="$PWD"
else
    # ai-contained mode: first positional arg is the workspace, remainder pass to claude.
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
    fi
    if [[ $# -lt 1 || -z "${COMPOSE_CMD:-}" ]]; then
        usage
    fi
    readonly WORKSPACE="$(realpath "$1" 2>/dev/null)"
    if [[ ! -d "$WORKSPACE" ]]; then
        echo "Error: '$1' is not a directory" >&2
        usage
    fi
    shift
fi

readonly COMPOSE_FILE="$SCRIPT_DIR/../docker-compose.yaml"
# Docker compose project names can only contain lowercase alphanumeric characters, hyphens, and underscores
readonly PROJECT="$(basename "${WORKSPACE}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9_-' '-' | sed 's/^-//;s/-$//')-$$"
readonly USER_ID="$(id -u)"
readonly GROUP_ID="$(id -g)"
readonly AI_CONTAINED_SECRETS_HOME="${AI_CONTAINED_SECRETS_HOME:-${HOME}/.config/ai-contained-secrets}"

# On first use, create the secrets root with owner-only perms so docker doesn't
# auto-create it as root. Subsequent runs leave the user's chosen perms alone.
if [[ ! -e "${AI_CONTAINED_SECRETS_HOME}" ]]; then
    mkdir -p "${AI_CONTAINED_SECRETS_HOME}"
    chmod 0700 "${AI_CONTAINED_SECRETS_HOME}"
fi

export WORKSPACE USER_ID GROUP_ID AI_CONTAINED_SECRETS_HOME

cleanup() {
    local -a cmd=(${COMPOSE_CMD} -f "${COMPOSE_FILE}" -p "${PROJECT}" down)
    if [[ -n "${DISABLE_CLEANUP:-}" ]]; then
        echo "DISABLE_CLEANUP set; skipping teardown. To clean up manually, run:" >&2
        # docker-compose.yaml uses ${VAR:?...} required-var syntax, so even `down`
        # fails to parse the file without these in the env — bake them into the line.
        printf '  USER_ID=%q GROUP_ID=%q WORKSPACE=%q AI_CONTAINED_SECRETS_HOME=%q' \
            "${USER_ID}" "${GROUP_ID}" "${WORKSPACE}" "${AI_CONTAINED_SECRETS_HOME}" >&2
        printf ' %q' "${cmd[@]}" >&2
        echo >&2
        return
    fi
    "${cmd[@]}"
}
trap cleanup EXIT

${COMPOSE_CMD} -f "${COMPOSE_FILE}" -p "${PROJECT}" run --rm -it agent "$@"
