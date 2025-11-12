#!/bin/sh
# Restart a node container by label filter
# Usage: restart-node.sh <label-filter>
# Example: restart-node.sh role=validator

set -e

if [ -z "$1" ]; then
  echo "Error: label filter required"
  echo "Usage: $0 <label-filter>"
  exit 1
fi

label_filter="$1"

container=$(docker ps -qf "label=$label_filter")

if [ -z "$container" ]; then
  echo "No container found with label=$label_filter"
  exit 1
fi

echo "Restarting container with label=$label_filter (container: $container)"
exec docker restart -s TERM "$container" > /dev/null
