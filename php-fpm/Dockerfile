# phpdock 定制：不走上游那套从头编译扩展的流程，直接用预构建镜像。
# 镜像来源：https://github.com/imzyf/phpdock-images
#
# LARADOCK_PHP_VERSION 由 overrides/php-fpm.yml 的 build.args 传入
# （值取自 .env 的 PHP_VERSION）。
# 本文件在 bin/.sync-config.sh 的 EXCLUDE_GLOBS 中，`make sync` 不会覆盖它。

ARG LARADOCK_PHP_VERSION
FROM yifans/phpdock:${LARADOCK_PHP_VERSION}-php-fpm

WORKDIR /var/www

CMD ["php-fpm"]

EXPOSE 9000
