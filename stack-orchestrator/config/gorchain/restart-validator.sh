#!/bin/sh

while true;
do
  sleep $RESTART_INTERVAL_SECONDS

  container=$(docker ps -qf "label=role=validator")
  echo "$(date): Restarting validator container"
  docker restart -s TERM $container
done
