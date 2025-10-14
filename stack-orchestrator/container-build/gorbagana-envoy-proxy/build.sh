#!/usr/bin/env bash
# Build gorbagana/envoy-proxy

source ${CERC_CONTAINER_BASE_DIR}/build-base.sh

# See: https://stackoverflow.com/a/246128/1701505
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

docker build -t gorbagana/envoy-proxy:local ${build_command_args} ${SCRIPT_DIR}
