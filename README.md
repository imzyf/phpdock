# PHPDOCK

## Introduction

My PHP development environment for Docker, built on
[Laradock](https://laradock.io/) with prebuilt php-fpm/workspace images
and local customizations layered on top (see "Syncing from upstream"
below).

## Quick Start

```bash
make up       # core containers: php-fpm, nginx, postgres, redis
make up-all   # all containers
make down
make build
docker-compose exec workspace bash
```

`make up`/`make up-all` create `.env` from `.env.example` on first run.
Edit `.env` to override defaults (`DATA_PATH_HOST`, `PHP_VERSION`,
`POSTGRES_VERSION`, etc.).

## Syncing from upstream

`php-fpm/`, `php-worker/`, `workspace/`, `.env.example` and
`docker-compose.yml` are mirrored unmodified from
[laradock/laradock](https://github.com/laradock/laradock). Local
customizations (default `.env` values, prebuilt-image Dockerfiles,
unused services/keys pruned) live in `bin/` and are layered back on
after syncing:

```bash
make sync
```

See `bin/.env.preference` and `bin/templates/` to change what gets
applied.

## References

- [Laradock.io](https://laradock.io/)
- [imzyf/phpdock-images](https://github.com/imzyf/phpdock-images)
