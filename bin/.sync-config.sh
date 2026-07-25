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

# 只镜像到 bin/.upstream/ 供对照的文件（本项目有手写的等价物，见各文件顶部注释）。
# 格式 "上游路径" 或 "上游路径:本地路径"（改名落地）。
SYNC_FILES=(
  .env.example:.env.upstream
  docker-compose.multi-php.yml:bin/.upstream/docker-compose.multi-php.yml
  docker-compose.yml:bin/.upstream/docker-compose.yml
  laradock:bin/.upstream/laradock
)

# 同步时「完全不碰」的路径：既不从上游复制，也不删除本地已有的同名文件。
# 因此这里同时用于两件事：
#   1. 保护本项目手写、且与上游同名的文件（三个 Dockerfile）；
#   2. 剪掉用不到的上游文件（那些 .ini 本地就不存在，跳过即保持不存在）。
#
# 服务的 compose.yml 不在此列 —— 它们从上游原样同步，本项目的定制放在
# <service>/compose.override.yml，由根 docker-compose.yml 的 include 列表合并上去。
EXCLUDE_GLOBS=(
  # 用不到的 PHP 版本 / 扩展配置，保持目录干净
  'php-fpm/aerospike.ini'
  'php-fpm/laravel.ini'
  'php-fpm/mysql.ini'
  'php-fpm/opcache.ini'
  'php-fpm/phalcon.ini'
  'php-fpm/php5*.ini'
  'php-fpm/php7*.ini'
  'php-fpm/php8.0.ini'
  'php-fpm/php8.1.ini'
  'php-fpm/php8.2.ini'
  'php-fpm/php8.3.ini'
  'php-fpm/php8.4.ini'
  # 改用自建预构建镜像的 Dockerfile（手写，不要被上游覆盖）
  'php-fpm/Dockerfile'
  'php-worker/Dockerfile'
  'workspace/Dockerfile'
)
