#!/usr/bin/env bash
#
# Shared config for bin/sync-upstream.sh and bin/prune-compose.sh.
# Sourced, not executed.

UPSTREAM_REPO="https://github.com/laradock/laradock.git"
IMAGES=(nginx php-fpm php-worker postgres redis workspace)
FILES=(.env.example docker-compose.yml)
# Services/volumes to keep in docker-compose.yml in addition to IMAGES.
# These have no own directory to sync (e.g. image-only services).
EXTRA_COMPOSE_SERVICES=(docker-in-docker)
