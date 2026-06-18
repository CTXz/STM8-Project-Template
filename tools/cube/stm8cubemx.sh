#!/usr/bin/env bash

set -euo pipefail

stm8cubemx_dir="${STM8CUBEMX_HOME:-/opt/st/stm8cubemx}"
warning_marker="${HOME}/.config/stm8-project-template/stm8cubemx-first-launch-warning-shown"
warning_delay="${STM8CUBEMX_FIRST_LAUNCH_WARNING_DELAY:-4}"

if [[ "${STM8CUBEMX_FIRST_LAUNCH_WARNING:-1}" != "0" && ! -e "${warning_marker}" ]]; then
  mkdir -p "$(dirname "${warning_marker}")"

  cat >&2 <<'EOF'

+---------------------------------+
| STM8CubeMX first-launch notes   |
+---------------------------------+

- STM8CubeMX 1.5.0 is an older Java/Swing application and needs X11 or
  XWayland display forwarding from the host.

- The first launch can take a few seconds while it creates user configuration.

STM8CubeMX will start shortly.

EOF

  touch "${warning_marker}"
  sleep "${warning_delay}"
fi

cd "${stm8cubemx_dir}"
exec ./STM8CubeMX "$@"
