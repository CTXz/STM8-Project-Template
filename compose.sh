#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-stm8-project-template}"
export HOST_UID="$(id -u)"
export HOST_GID="$(id -g)"
export PROJECT_ROOT="${SCRIPT_DIR}"
export STM8_IMAGE="${STM8_IMAGE:-ghcr.io/ctxz/stm8-toolchain:latest}"
export CUBE_IMAGE="${CUBE_IMAGE:-stm8-project-template-cube:java8}"

if [[ -n "${XAUTHORITY:-}" && -e "${XAUTHORITY}" ]]; then
  export XAUTHORITY_PATH="${XAUTHORITY}"
elif [[ -e "${HOME}/.Xauthority" ]]; then
  export XAUTHORITY_PATH="${HOME}/.Xauthority"
else
  export XAUTHORITY_PATH="/dev/null"
fi

export CUBE_XDG_RUNTIME_DIR="/tmp/wayland"
export CUBE_GUI_BACKEND="${CUBE_GUI_BACKEND:-x11}"
export CUBE_WAYLAND_DISPLAY=""
export CUBE_WAYLAND_MOUNT_NAME="${WAYLAND_DISPLAY:-wayland-0}"
export CUBE_WAYLAND_SOCKET="/dev/null"
export CUBE_GDK_BACKEND="${CUBE_GDK_BACKEND:-}"
export CUBE_DISPLAY_BACKEND="x11"

case "${CUBE_GUI_BACKEND}" in
  x11|wayland|auto)
    ;;
  *)
    echo "Unsupported CUBE_GUI_BACKEND: ${CUBE_GUI_BACKEND}" >&2
    echo "Supported values: x11, wayland, auto" >&2
    exit 2
    ;;
esac

wayland_socket=""
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  if [[ "${WAYLAND_DISPLAY}" == /* ]]; then
    wayland_socket="${WAYLAND_DISPLAY}"
    export CUBE_WAYLAND_MOUNT_NAME="$(basename "${WAYLAND_DISPLAY}")"
  elif [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
    wayland_socket="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
    export CUBE_WAYLAND_MOUNT_NAME="${WAYLAND_DISPLAY}"
  fi
fi

if [[ "${CUBE_GUI_BACKEND}" != "x11" && -n "${wayland_socket}" && -S "${wayland_socket}" ]]; then
  export CUBE_WAYLAND_DISPLAY="${CUBE_WAYLAND_MOUNT_NAME}"
  export CUBE_WAYLAND_SOCKET="${wayland_socket}"
  export CUBE_GDK_BACKEND="${CUBE_GDK_BACKEND:-wayland,x11}"
  export CUBE_DISPLAY_BACKEND="wayland"
elif [[ "${CUBE_GUI_BACKEND}" == "wayland" ]]; then
  export CUBE_GDK_BACKEND="${CUBE_GDK_BACKEND:-wayland,x11}"
  export CUBE_DISPLAY_BACKEND="wayland-missing"
else
  export CUBE_GDK_BACKEND="${CUBE_GDK_BACKEND:-x11}"
fi

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
  stm8cubemx      Start STM8CubeMX in the GUI container
  cubemx          Alias for stm8cubemx
  cube-shell      Drop into a shell in the STM8CubeMX GUI container
  cube-image      Build the STM8CubeMX GUI image
            --stm8cubemxzip <path>
                      Use this STM8CubeMX installer ZIP non-interactively
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
  ./compose.sh stm8cubemx
  ./compose.sh cube-shell
  ./compose.sh cube-image --stm8cubemxzip stm8cubemx.zip
EOF
}

image_exists() {
  docker image inspect "${STM8_IMAGE}" >/dev/null 2>&1
}

cube_image_exists() {
  docker image inspect "${CUBE_IMAGE}" >/dev/null 2>&1
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

abs_path() {
  local path="$1"
  if [[ "${path}" == /* ]]; then
    printf '%s\n' "${path}"
  else
    printf '%s\n' "${SCRIPT_DIR}/${path#./}"
  fi
}

path_for_docker_context() {
  local path abs
  path="$1"
  abs="$(abs_path "${path}")"

  if [[ ! -f "${abs}" ]]; then
    echo "Installer file not found: ${path}" >&2
    exit 1
  fi

  case "${abs}" in
    "${SCRIPT_DIR}"/*)
      printf '%s\n' "${abs#"${SCRIPT_DIR}/"}"
      ;;
    *)
      cat >&2 <<EOF
Installer file is outside the Docker build context:
  ${path}

Place it in the repository root, or pass a path under:
  ${SCRIPT_DIR}
EOF
      exit 1
      ;;
  esac
}

validate_stm8cubemx_zip() {
  local path="$1" listing
  listing="$(unzip -Z1 "$(abs_path "${path}")")"
  grep -Eq '(^|/)SetupSTM8CubeMX-[^/]+\.exe$' <<<"${listing}" \
    && grep -Eq '(^|/)SetupSTM8CubeMX-[^/]+\.linux$' <<<"${listing}"
}

print_stm8cubemx_download_instructions() {
  cat >&2 <<'EOF'
The STM8CubeMX installer ZIP is required to build the GUI image.

Download STM8CubeMX for Linux from ST, then place the ZIP file in the
repository root and rerun:
  ./compose.sh cube-image

Expected ZIP contents include:
  SetupSTM8CubeMX-<version>.exe
  SetupSTM8CubeMX-<version>.linux

For non-interactive use:
  ./compose.sh cube-image --stm8cubemxzip <path>
EOF
}

find_root_zips() {
  find "${SCRIPT_DIR}" -maxdepth 1 -type f -iname '*.zip' -printf '%f\n' | sort -V
}

choose_stm8cubemx_zip() {
  local provided candidates candidate answer
  provided="$1"

  if [[ -n "${provided}" ]]; then
    if ! validate_stm8cubemx_zip "${provided}"; then
      echo "STM8CubeMX ZIP does not have the expected installer layout: ${provided}" >&2
      exit 1
    fi
    path_for_docker_context "${provided}"
    return
  fi

  mapfile -t candidates < <(find_root_zips)

  if [[ "${#candidates[@]}" -eq 0 ]]; then
    print_stm8cubemx_download_instructions

    if [[ -t 0 ]]; then
      echo >&2
      read -r -p "After placing the STM8CubeMX ZIP in the repository root, press Enter to rescan or Ctrl-C to stop. " _
      mapfile -t candidates < <(find_root_zips)
    fi
  fi

  if [[ "${#candidates[@]}" -eq 0 ]]; then
    echo "No STM8CubeMX ZIP found in the repository root." >&2
    exit 1
  fi

  local -a valid_candidates=()
  for candidate in "${candidates[@]}"; do
    if validate_stm8cubemx_zip "${candidate}"; then
      valid_candidates+=("${candidate}")
    fi
  done

  if [[ "${#valid_candidates[@]}" -eq 0 ]]; then
    echo "No STM8CubeMX installer ZIP with the expected layout was found in the repository root." >&2
    printf '  %s\n' "${candidates[@]}" >&2
    exit 1
  fi

  if [[ "${#valid_candidates[@]}" -eq 1 ]]; then
    candidate="${valid_candidates[0]}"

    if [[ -t 0 ]]; then
      read -r -p "Use STM8CubeMX installer '${candidate}'? [Y/n] " answer
      case "${answer,,}" in
        ""|y|yes)
          ;;
        *)
          echo "Declined STM8CubeMX installer: ${candidate}" >&2
          exit 1
          ;;
      esac
    fi

    path_for_docker_context "${candidate}"
    return
  fi

  if [[ ! -t 0 ]]; then
    echo "Multiple STM8CubeMX ZIPs found. Rerun with --stm8cubemxzip <path>." >&2
    printf '  %s\n' "${valid_candidates[@]}" >&2
    exit 1
  fi

  echo "Multiple STM8CubeMX ZIPs found:" >&2
  select candidate in "${valid_candidates[@]}"; do
    if [[ -z "${candidate:-}" ]]; then
      echo "Invalid selection." >&2
      continue
    fi
    path_for_docker_context "${candidate}"
    return
  done
}

stm8cubemx_zip_arg="${STM8CUBEMX_ZIP:-}"

parse_cube_image_options() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stm8cubemxzip)
        if [[ $# -lt 2 ]]; then
          echo "--stm8cubemxzip requires a path" >&2
          exit 2
        fi
        stm8cubemx_zip_arg="$2"
        shift
        ;;
      --stm8cubemxzip=*)
        stm8cubemx_zip_arg="${1#*=}"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option for cube-image: $1" >&2
        usage
        exit 2
        ;;
    esac
    shift
  done
}

ensure_stm8cubemx_installer() {
  export STM8CUBEMX_ZIP
  STM8CUBEMX_ZIP="$(choose_stm8cubemx_zip "${stm8cubemx_zip_arg}")"
  printf 'Using STM8CubeMX installer: %s\n' "${STM8CUBEMX_ZIP}" >&2
}

ensure_cube_image() {
  if cube_image_exists; then
    return
  fi

  ensure_stm8cubemx_installer
  docker compose build cube
}

ensure_gui_display() {
  if [[ "${CUBE_DISPLAY_BACKEND}" == "wayland" || -n "${DISPLAY:-}" ]]; then
    return
  fi

  if [[ "${CUBE_DISPLAY_BACKEND}" == "wayland-missing" ]]; then
    cat >&2 <<'EOF'
CUBE_GUI_BACKEND=wayland was requested, but no valid Wayland socket was found.

On a Linux Wayland desktop, run this from a graphical terminal so XDG_RUNTIME_DIR
and WAYLAND_DISPLAY are set.
EOF
  else
    cat >&2 <<'EOF'
DISPLAY is not set, so the GUI container cannot open a window.

On a Linux/X11 or XWayland desktop, allow local container access and retry:
  xhost +SI:localuser:$(id -un)
  ./compose.sh stm8cubemx
EOF
  fi
  exit 1
}

ensure_stm8cubemx_display() {
  ensure_gui_display

  if [[ -n "${DISPLAY:-}" ]]; then
    return
  fi

  cat >&2 <<'EOF'
STM8CubeMX is Java/Swing-based and currently needs X11 or XWayland.

A native Wayland socket was detected, but DISPLAY is not set. Start STM8CubeMX
from a session that provides XWayland, then retry:
  ./compose.sh stm8cubemx
EOF
  exit 1
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
  stm8cubemx|cubemx)
    ensure_stm8cubemx_display
    ensure_cube_image
    compose_run cube /workspace/tools/cube/stm8cubemx.sh "$@"
    ;;
  cube-shell)
    ensure_cube_image
    compose_run cube bash "$@"
    ;;
  cube-image)
    parse_cube_image_options "$@"
    ensure_stm8cubemx_installer
    docker compose build cube
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
