# phpdock 定制：不走上游那套从头编译扩展的流程，直接用预构建镜像。
# 镜像由 images/php-fpm/Dockerfile 构建，发布流程见 .github/workflows/laradock-image.yml。
#
# LARADOCK_PHP_VERSION 由 php-fpm/compose.override.yml 的 build.args 传入
# （值取自 .env 的 PHP_VERSION）。
# 本文件在 .github/scripts/.sync-config.sh 的 EXCLUDE_GLOBS 中，`make sync` 不会覆盖它。

ARG LARADOCK_PHP_VERSION
FROM ghcr.io/imzyf/phpdock/php-fpm:${LARADOCK_PHP_VERSION}

WORKDIR /var/www

CMD ["php-fpm"]

EXPOSE 9000
