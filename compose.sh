#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-stm8-project-template}"
export HOST_UID="$(id -u)"
export HOST_GID="$(id -g)"
export PROJECT_ROOT="${SCRIPT_DIR}"
export STM8_IMAGE="${STM8_IMAGE:-ghcr.io/ctxz/stm8-toolchain:latest}"

usage() {
  cat <<'EOF'
Usage: ./compose.sh <command> [options]

Commands:
  build           Build the firmware in the container (default)
            --shell   Drop into a shell in the build container instead of running make
  flash           Flash the STM8 via stm8flash inside the container
            --shell   Drop into a shell in the flash container instead of flashing
  upload          Alias for flash
  clean           Remove build artifacts (runs 'make clean' in the container)
  image           Force a local build of the toolchain image
  help            Show this message

Any extra arguments are forwarded to make, e.g.:
  ./compose.sh build hex
  ./compose.sh flash FLASH_FLAGS="-c stlinkv2 -p stm8s103f3"

The toolchain image is pulled from ${STM8_IMAGE} on first use. If the pull
fails (e.g. offline, or the registry is unreachable), it is built locally from
the Dockerfile instead. Building locally compiles the toolchain from source and
can take 30-60 minutes.

Examples:
  ./compose.sh build
  ./compose.sh build --shell
  ./compose.sh flash
  ./compose.sh flash --shell
EOF
}

image_exists() {
  docker image inspect "${STM8_IMAGE}" >/dev/null 2>&1
}

build_image_locally() {
  echo "Building toolchain image locally from Dockerfile (this can take 30-60 min)..." >&2
  docker compose build build
}

# Make sure the toolchain image is available: try to pull it, and fall back to a
# local build if the pull fails.
ensure_image() {
  if image_exists; then
    return
  fi

  echo "Pulling toolchain image ${STM8_IMAGE}..." >&2
  if docker pull "${STM8_IMAGE}"; then
    return
  fi

  echo "Pull failed; falling back to a local build." >&2
  build_image_locally
}

compose_run() {
  local service="$1"
  shift
  docker compose run --rm "${service}" "$@"
}

# Split off a leading --shell flag; everything else is forwarded to make.
parse_options() {
  shell=false
  forward=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --shell)
        shell=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        forward+=("$1")
        ;;
    esac
    shift
  done
}

cmd="build"
if [[ $# -gt 0 && "${1}" != -* ]]; then
  cmd="$1"
  shift
fi

case "${cmd}" in
  build)
    parse_options "$@"
    ensure_image
    if [[ "${shell}" == "true" ]]; then
      compose_run build bash
    else
      compose_run build make "${forward[@]}"
    fi
    ;;
  flash|upload)
    parse_options "$@"
    ensure_image
    if [[ "${shell}" == "true" ]]; then
      compose_run flash bash
    else
      compose_run flash make flash "${forward[@]}"
    fi
    ;;
  clean)
    parse_options "$@"
    ensure_image
    compose_run build make clean "${forward[@]}"
    ;;
  image)
    build_image_locally
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: ${cmd}" >&2
    usage
    exit 2
    ;;
esac
