# Gorchain restarter image

Supervisor image combining Docker CLI and supercronic for scheduled container restarts.

## Base image
- `docker:27-cli-alpine` - provides Docker CLI for container management

## Installed tools
- supercronic v0.2.33 - cron-like job runner for containers

## Usage
Used in the gorchain stack to restart validator and RPC nodes on a schedule.
