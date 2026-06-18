#!/usr/bin/env bash

set -euo pipefail

uid="${HOST_UID:-1000}"
gid="${HOST_GID:-1000}"
user="${CONTAINER_USER:-developer}"
home_dir="/home/${user}"
run_user="${user}"

if ! getent group "${gid}" >/dev/null; then
  groupadd --gid "${gid}" hostuser
fi

if entry="$(getent passwd "${uid}")"; then
  run_user="$(printf '%s' "${entry}" | cut -d: -f1)"
  current_home="$(printf '%s' "${entry}" | cut -d: -f6)"

  if [[ "${run_user}" != "${user}" ]] && ! getent passwd "${user}" >/dev/null; then
    usermod --login "${user}" "${run_user}"
    run_user="${user}"
  fi

  if [[ "${current_home}" != "${home_dir}" ]]; then
    usermod --home "${home_dir}" "${run_user}"
  fi
else
  create_home_flag="--create-home"
  if [[ -d "${home_dir}" ]]; then
    create_home_flag="--no-create-home"
  fi

  useradd "${create_home_flag}" --home-dir "${home_dir}" --shell /bin/bash \
    --uid "${uid}" --gid "${gid}" "${user}" >/dev/null
fi

mkdir -p \
  "${home_dir}/.cache" \
  "${home_dir}/.config" \
  "${home_dir}/STM8Cube"

mkdir -p /tmp/wayland
chown "${uid}:${gid}" /tmp/wayland
chmod 700 /tmp/wayland

if [[ ! -e "${home_dir}/stm8-project-template" ]]; then
  ln -s /workspace "${home_dir}/stm8-project-template"
fi

chown -R "${uid}:${gid}" "${home_dir}"

export HOME="${home_dir}"
exec gosu "${uid}:${gid}" env HOME="${home_dir}" USER="${run_user}" LOGNAME="${run_user}" "$@"
