#!/usr/bin/env bash
# Build gorbagana/gorchain-validator

source ${CERC_CONTAINER_BASE_DIR}/build-base.sh

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Use the Dockerfile from the gorchain repo
GORCHAIN_REPO=${CERC_REPO_BASE_DIR}/gorchain

if [ ! -d "$GORCHAIN_REPO" ]; then
  echo "Error: gorchain repository not found at $GORCHAIN_REPO"
  exit 1
fi

docker build --platform linux/amd64 -t gorbagana/gorchain-validator:local \
  -f ${SCRIPT_DIR}/Dockerfile \
  ${build_command_args} \
  ${GORCHAIN_REPO}
