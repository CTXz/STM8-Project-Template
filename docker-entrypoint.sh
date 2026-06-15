#!/usr/bin/env bash
set -e

# shellcheck source=/opt/stm8-toolchain/env.sh
source /opt/stm8-toolchain/env.sh

exec "$@"
