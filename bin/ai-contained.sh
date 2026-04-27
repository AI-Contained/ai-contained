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

export WORKSPACE USER_ID GROUP_ID

cleanup() { ${COMPOSE_CMD} -f "${COMPOSE_FILE}" -p "${PROJECT}" down; }
trap cleanup EXIT

${COMPOSE_CMD} -f "${COMPOSE_FILE}" -p "${PROJECT}" run --rm -it agent "${@:2}"
