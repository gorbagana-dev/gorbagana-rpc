#!/usr/bin/env bash
set -e
if [ -n "$CERC_SCRIPT_DEBUG" ]; then
  set -x
fi

SO_COMMAND="laconic-so --verbose"

test_dir=$(readlink -f "$(dirname -- "${BASH_SOURCE[0]}")")
test_name=$(basename "$test_dir")
repo_root=$(readlink -f "$test_dir/../..")

stack_path=$repo_root/stack-orchestrator/stacks/gorchain

log_info () {
  local message="$1"
  echo "$(date +"%Y-%m-%d %T"): ${message}" 1>&2
}

fail_exit () {
  local fail_message=$1
  log_info "${test_name}: ${fail_message}"
  log_info "${test_name}: FAILED"
  exit 1
}

# Sanity check the stack dir exists
if [ ! -d "${stack_path}" ]; then
  fail_exit "stack directory not present"
fi

test_workdir=$(mktemp -p /tmp -d "test_${test_name}.XXXXXX")
mkdir "$test_workdir/repo"

export CERC_REPO_BASE_DIR=$test_workdir/repo

reported_version_string=$( $SO_COMMAND version )
log_info "SO version is: ${reported_version_string}"

log_info "Cloning repositories into: $CERC_REPO_BASE_DIR"
rm -rf $CERC_REPO_BASE_DIR
mkdir -p $CERC_REPO_BASE_DIR

$SO_COMMAND --stack ${stack_path} setup-repositories --git-ssh

log_info "Building containers"
$SO_COMMAND --stack ${stack_path} build-containers

test_deployment_dir=$test_workdir/deployment
test_deployment_spec=$test_workdir/deployment-spec.yml

$SO_COMMAND --stack ${stack_path} deploy init --output $test_deployment_spec
# Check the file now exists
if [ ! -f "$test_deployment_spec" ]; then
  fail_exit "deploy init test: spec file not present"
fi

$SO_COMMAND --stack ${stack_path} deploy create --spec-file $test_deployment_spec --deployment-dir $test_deployment_dir
# Check the deployment dir exists
if [ ! -d "$test_deployment_dir" ]; then
  fail_exit "deploy create test: deployment directory not present"
fi
log_info "deploy create test: passed"

$SO_COMMAND deployment --dir $test_deployment_dir start

cleanup() {
  $SO_COMMAND deployment --dir $test_deployment_dir stop --delete-volumes
}
trap cleanup EXIT

timeout=900 # 15 minutes
log_info "Waiting for validator to start. Timeout set to $timeout seconds"
start_time=$(date +%s)
elapsed_time=0
validator_started=false

# Wait for validator RPC to become available
while [ "$validator_started" = false ] && [ $elapsed_time -lt $timeout ]; do
  sleep 10
  log_info "Checking validator health..."

  # Try to get health status from RPC
  if $SO_COMMAND deployment --dir $test_deployment_dir exec agave-validator "curl -sf http://localhost:8899/health" > /dev/null 2>&1; then
    validator_started=true
    log_info "Validator RPC is responding"
  fi

  current_time=$(date +%s)
  elapsed_time=$((current_time - start_time))
done

if [ "$validator_started" = false ]; then
  fail_exit "Validator did not start within $timeout seconds"
fi

# Get initial slot number
log_info "Getting initial slot number"
initial_slot=0
initial_slot=$($SO_COMMAND deployment --dir $test_deployment_dir exec agave-validator \
  "curl -s -X POST -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getSlot\"}' http://localhost:8899" \
  | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "0")

log_info "Initial slot: $initial_slot"

# Wait for slot progression
timeout=300
log_info "Waiting for slot progression. Timeout set to $timeout seconds"
start_time=$(date +%s)
elapsed_time=0
subsequent_slot=$initial_slot

# Wait for at least 10 slots to progress or timeout
while [ "$subsequent_slot" -le $((initial_slot + 10)) ] && [ $elapsed_time -lt $timeout ]; do
  sleep 10
  log_info "Waiting for slot progression..."

  subsequent_slot=$($SO_COMMAND deployment --dir $test_deployment_dir exec agave-validator \
    "curl -s -X POST -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getSlot\"}' http://localhost:8899" \
    | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "$subsequent_slot")

  log_info "Current slot: $subsequent_slot"

  current_time=$(date +%s)
  elapsed_time=$((current_time - start_time))
done

slot_difference=$((subsequent_slot - initial_slot))

log_info "Initial slot: $initial_slot"
log_info "Subsequent slot: $subsequent_slot"
log_info "Slot difference: $slot_difference"

# Slot difference should be at least 10
if [[ $slot_difference -ge 10 ]]; then
  log_info "Test passed: validator is producing slots"
  test_result=0
else
  log_info "Test failed: slots did not progress sufficiently (initial: ${initial_slot}, subsequent: ${subsequent_slot})"
  log_info "Logs from stack:"
  $SO_COMMAND deployment --dir $test_deployment_dir logs
  test_result=1
fi

exit $test_result
