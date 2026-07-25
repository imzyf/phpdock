.DEFAULT_GOAL := help

.PHONY: help sync sync-force generate config up up-all down build

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} \
		/^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next} \
		/^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' \
		$(MAKEFILE_LIST)

##@ Sync

sync: ## Pull latest files from upstream, regenerate, then review with `git diff`
	bin/sync-upstream.sh
	@$(MAKE) --no-print-directory generate
	@$(MAKE) --no-print-directory config >/dev/null \
		&& echo "==> docker compose config OK. Review upstream changes: git diff"

sync-force: ## Sync from upstream, ignoring the clone cache
	LCC_SYNC_CACHE_TTL=0 $(MAKE) sync

generate: ## Regenerate docker-compose.yml from upstream + */compose.override.yml
	bin/generate-docker-compose.sh

##@ Docker

config: .env ## Print the fully merged compose config (upstream + */compose.override.yml)
	docker-compose config

up: .env ## Start core containers (php-fpm, nginx, postgres, redis)
	docker-compose up -d php-fpm nginx postgres redis

up-all: .env ## Start all containers
	docker-compose up -d

down: ## Stop and remove all containers
	docker-compose down

build: ## Build (or rebuild) core images
	docker-compose build php-fpm nginx postgres redis

.env:
	@if [ ! -f .env ]; then cp .env.example .env; fi
