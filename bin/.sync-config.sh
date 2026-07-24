#!/usr/bin/env bash
#
# bin/sync-upstream.sh 的共享配置（被 source 引入，而非执行）。

# 按需修改以下变量以匹配你的上游仓库。
UPSTREAM_REPO="https://github.com/laradock/laradock.git"
UPSTREAM_BRANCH="master"

# 从上游镜像的目录（仅刷新上游拥有的条目，本地新增文件保留）。
SYNC_DIRS=(
  docker-in-docker
  nginx
  php-fpm
  php-worker
  postgres
  redis
  workspace
)

# 要从上游拉取的独立文件。格式 "上游路径" 或 "上游路径:本地路径"（改名落地）。
SYNC_FILES=(
  .env.example:.upstream/.env.example
  docker-compose.multi-php.yml:.upstream/docker-compose.multi-php.yml
  docker-compose.yml:.upstream/docker-compose.yml
  laradock:.upstream/laradock
)

# 从同步中排除的本地化文件（rsync --exclude）。
EXCLUDE_GLOBS=(
  'php-fpm/php5*.ini'
  'php-fpm/php7*.ini'
  'php-fpm/php8.0.ini'
  'php-fpm/php8.1.ini'
  'php-fpm/php8.2.ini'
  'php-fpm/php8.3.ini'
  'php-fpm/php8.4.ini'
  'php-fpm/Dockerfile'
  'php-worker/Dockerfile'
  'workspace/Dockerfile'
)
