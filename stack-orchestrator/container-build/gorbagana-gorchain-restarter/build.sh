#!/usr/bin/env bash
source ${CERC_CONTAINER_BASE_DIR}/build-base.sh

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

docker build --platform linux/amd64 -t gorbagana/gorchain-restarter:local \
  -f ${SCRIPT_DIR}/Dockerfile \
  ${build_command_args} \
  ${SCRIPT_DIR}
