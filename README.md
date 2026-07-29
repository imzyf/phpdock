# PHPDOCK

English · [简体中文](README.zh-CN.md)

A PHP development environment for Docker — [Laradock](https://laradock.io/)
kept intact underneath, with prebuilt images on top.

## Why

Laradock is excellent, but using it means forking it: you edit its files,
and every upstream update becomes a manual merge. It ships ~150 services
you will never start, and builds every PHP extension from source, so a
first `build` costs tens of minutes.

PHPDOCK answers all three without leaving Laradock behind:

- **Never fork.** Upstream files are copied in verbatim and refreshed by
  `make sync`. Local customizations live *beside* them in
  `<service>/compose.override.yml`, which Docker Compose merges natively.
  A weekly GitHub Action runs the sync and opens a PR — upstream changes
  arrive as a reviewable diff, never as a conflict.
- **Never compile.** The three Dockerfiles are a one-line `FROM` on a
  prebuilt image from [imzyf/phpdock-images](https://github.com/imzyf/phpdock-images).
  Startup is seconds, not minutes.
- **Keep only what you run.** Trimming is declarative, not a one-time
  hand edit: `SYNC_DIRS` in `bin/.sync-config.sh` is the list of services
  that survive, and both `make sync` and the generated root compose
  follow it. `EXCLUDE_GLOBS` does the same at file level, so a service
  you keep stops dragging in config for PHP versions you'll never run.
  Want MySQL instead of Postgres, or MailHog back? Edit one list, run
  `make sync`.

## Quick start

`make generate` requires [yq](https://github.com/mikefarah/yq) v4.

```bash
make up       # php-fpm, nginx, postgres, redis
make up-all   # everything
make down
docker compose exec workspace bash
```

`make up` creates `.env` from `.env.example` on first run. `make help`
lists the rest.

## Which file do I edit?

`.env.example` holds **only** the values that differ from upstream —
everything else falls back to `.env.upstream` and `<service>/defaults.env`.
Your `.env` always wins.

| File | Owner |
|---|---|
| `<service>/compose.yml`, `<service>/defaults.env` | upstream — refreshed by `make sync`, don't edit |
| `<service>/compose.override.yml` | **you** — merged onto the upstream compose |
| `php-fpm/`, `php-worker/`, `workspace/` Dockerfiles | **you** — one-line `FROM` on a prebuilt image |
| `.env.example` | **you** — shared settings and overrides |
| `bin/.sync-config.sh` | **you** — which services and files to keep |
| `docker-compose.yml` | generated — run `make generate` |

To customize a service, drop a `compose.override.yml` into its directory
and run `make generate`; the root `include` list is wired up for you.
Check the result with `docker compose config`. To see everything
customized so far:
`ls */compose.override.yml`.

## Staying current

```bash
make sync         # pull upstream, regenerate, then review with `git diff`
make sync-force   # ignore the 1-day clone cache
```

What gets synced, what is protected from sync, and how the root compose
file is generated are documented at the top of `bin/.sync-config.sh`,
`bin/sync-upstream.sh`, and `bin/generate-docker-compose.sh`.
