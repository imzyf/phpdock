# PHPDOCK

[English](README.md) · 简体中文

一套 Docker 上的 PHP 开发环境 —— 底下原封不动地跑着 [Laradock](https://laradock.io/)，上面盖一层预构建镜像。

## 为什么

Laradock 很好，但用它基本等于 fork 它：你改的是它的文件，于是上游每次更新都变成一次手工合并。它带着约 150 个你永远不会启动的服务，还会从源码编译每一个 PHP 扩展，第一次 `build` 要花掉几十分钟。

PHPDOCK 在不抛弃 Laradock 的前提下解决这三件事：

- **不 fork。** 上游文件原样复制进来，由 `make sync` 刷新。本项目的定制放在它们*旁边*的 `<service>/compose.override.yml`，交给 Docker Compose 原生合并。每周一个 GitHub Action 跑同步并自动开 PR —— 上游的变更以一份可审阅的 diff 抵达，而不是一堆冲突。
- **不编译。** 三个 Dockerfile 各自只有一行 `FROM`，指向 [imzyf/phpdock-images](https://github.com/imzyf/phpdock-images) 的预构建镜像。启动以秒计，不是以分钟计。
- **只留会跑的。** 裁剪是声明式的，不是一次性手工删文件：`bin/.sync-config.sh` 里的 `SYNC_DIRS` 就是「保留哪些服务」的清单，`make sync` 和生成出来的根 compose 都跟着它走。`EXCLUDE_GLOBS` 在文件级做同样的事，于是保留下来的服务也不会拖着一堆你永远用不到的 PHP 版本配置。想把 Postgres 换成 MySQL、或者把 MailHog 加回来？改一行清单，跑 `make sync`。

## 快速开始

`make generate` 需要 [yq](https://github.com/mikefarah/yq) v4。

```bash
make up       # php-fpm, nginx, postgres, redis
make up-all   # 全部
make down
docker compose exec workspace bash
```

首次运行 `make up` 会从 `.env.example` 生成 `.env`。其余命令见 `make help`。

## 我该改哪个文件

`.env.example` **只**放与上游不同的值 —— 其余一律回落到 `.env.upstream` 和 `<service>/defaults.env`。你的 `.env` 永远说了算。

| 文件 | 归属 |
|---|---|
| `<service>/compose.yml`、`<service>/defaults.env` | 上游 —— 由 `make sync` 刷新，别改 |
| `<service>/compose.override.yml` | **你的** —— 合并到上游 compose 之上 |
| `php-fpm/`、`php-worker/`、`workspace/` 的 Dockerfile | **你的** —— 一行 `FROM` 指向预构建镜像 |
| `.env.example` | **你的** —— 公共设置与覆盖项 |
| `bin/.sync-config.sh` | **你的** —— 保留哪些服务、哪些文件 |
| `docker-compose.yml` | 生成的 —— 跑 `make generate` |

要定制某个服务，往它的目录里丢一个 `compose.override.yml`，再跑 `make generate`，根目录的 `include` 列表会自动接好。用 `docker compose config` 检查结果。想看目前定制了哪些：`ls */compose.override.yml`。

## 跟上上游

```bash
make sync         # 拉取上游、重新生成，然后用 `git diff` 审阅
make sync-force   # 忽略 1 天的克隆缓存
```

同步哪些文件、哪些文件受保护不被同步、根 compose 文件如何生成，都写在 `bin/.sync-config.sh`、`bin/sync-upstream.sh`、`bin/generate-docker-compose.sh` 三个脚本的开头注释里。
