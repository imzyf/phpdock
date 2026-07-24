.DEFAULT_GOAL := help

.PHONY: help sync sync-force customized up up-all down build

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} \
		/^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next} \
		/^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' \
		$(MAKEFILE_LIST)

##@ Sync

sync: ## Pull latest files from upstream, then regenerate .env.laradock
	bin/sync-upstream.sh
	make customized

sync-force: ## Sync from upstream, ignoring the clone cache
	LCC_SYNC_CACHE_TTL=0 make sync

customized: ## Regenerate customized compose, env, and Dockerfiles
	bin/generate-docker-compose.sh
	bin/generate-env-example.sh
	bin/generate-dockerfiles.sh
	bin/generate-service-compose.sh

##@ Docker

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
