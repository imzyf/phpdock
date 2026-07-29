.DEFAULT_GOAL := help

# Compose v2 (the `docker compose` plugin). GitHub runners no longer ship the
# standalone v1 binary, so `docker-compose` is not a portable spelling.
# Override with `make COMPOSE=docker-compose <target>` if you still need v1.
COMPOSE ?= docker compose

.PHONY: help sync sync-force generate up up-all down build

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} \
		/^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next} \
		/^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' \
		$(MAKEFILE_LIST)

##@ Sync

sync: .env ## Pull latest files from upstream, regenerate, then review with `git diff`
	bin/sync-upstream.sh
	@$(MAKE) --no-print-directory generate
	@$(COMPOSE) config >/dev/null \
		&& echo "==> docker compose config OK. Review upstream changes: git diff"

sync-force: ## Sync from upstream, ignoring the clone cache
	LCC_SYNC_CACHE_TTL=0 $(MAKE) sync

generate: ## Regenerate docker-compose.yml from upstream + */compose.override.yml
	bin/generate-docker-compose.sh

##@ Docker

up: .env ## Start core containers (php-fpm, nginx, postgres, redis)
	$(COMPOSE) up -d php-fpm nginx postgres redis

up-all: .env ## Start all containers
	$(COMPOSE) up -d

down: ## Stop and remove all containers
	$(COMPOSE) down

build: ## Build (or rebuild) core images
	$(COMPOSE) build php-fpm nginx postgres redis

.env:
	@if [ ! -f .env ]; then cp .env.example .env; fi
