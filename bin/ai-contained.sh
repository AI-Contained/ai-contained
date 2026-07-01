#!/bin/bash
set -euo pipefail

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
    echo "Usage: $(basename "$0") <path>"
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

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

if [[ $# -lt 1 || -z "${COMPOSE_CMD:-}" ]]; then
    usage
fi

readonly WORKSPACE="$(realpath "$1")"
readonly COMPOSE_FILE="$(dirname "$0")/../docker-compose.yaml"
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

${COMPOSE_CMD} -f "${COMPOSE_FILE}" -p "${PROJECT}" run --rm -it agent "${@:2}"
