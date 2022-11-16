.DEFAULT_GOAL := help

.PHONY: help sync up up-all down build

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

sync: ## Sync upstream laradock
	bin/sync-upstream.sh
	bin/prune-compose.sh
	bin/apply-env-preference.sh
	bin/prune-php-ini.sh
	bin/prune-build-args.sh
	bin/patch-postgres-data-path.sh
	bin/apply-templates.sh
## must last one
	bin/prune-unused-env.sh

up: .env ## Start core containers (php-fpm, nginx)
	docker-compose up -d php-fpm nginx postgres redis

up-all: .env ## Start all containers
	docker-compose up -d

.env:
	@if [ ! -f .env ]; then cp .env.example .env; fi

down: ## Stop and remove all containers
	docker-compose down

build: ## Build (or rebuild) all images
	docker-compose build php-fpm nginx postgres redis
