# Apache httpd 2.4 + AEM Dispatcher module 4.3.8 (OpenSSL 3 build)
# Arch-aware: works natively on Intel (amd64) and Apple Silicon (arm64).
# Build context must be the repository root (needs binaries/).
FROM httpd:2.4

ARG TARGETARCH
ARG DISPATCHER_VERSION=4.3.8

COPY binaries/dispatcher-apache2.4-linux-*-ssl3.0-${DISPATCHER_VERSION}.tar.gz /tmp/

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) DISP_ARCH=x86_64 ;; \
      arm64) DISP_ARCH=aarch64 ;; \
      *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac; \
    mkdir /tmp/disp && tar -xzf "/tmp/dispatcher-apache2.4-linux-${DISP_ARCH}-ssl3.0-${DISPATCHER_VERSION}.tar.gz" -C /tmp/disp; \
    cp "/tmp/disp/dispatcher-apache2.4-${DISPATCHER_VERSION}.so" /usr/local/apache2/modules/mod_dispatcher.so; \
    mkdir -p /var/cache/dispatcher /usr/local/apache2/conf/dispatcher; \
    chown -R www-data:www-data /var/cache/dispatcher; \
    rm -rf /tmp/disp /tmp/*.tar.gz

COPY docker/dispatcher/conf/dispatcher.conf /usr/local/apache2/conf/dispatcher/dispatcher.conf
COPY docker/dispatcher/conf/publish-farm.any /usr/local/apache2/conf/dispatcher/publish-farm.any

RUN printf '\nInclude conf/dispatcher/dispatcher.conf\n' >> /usr/local/apache2/conf/httpd.conf

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=5 \
  CMD httpd -t || exit 1

EXPOSE 80
