ARG DISTRO="alpine"
ARG PHP_VERSION=8.2

FROM docker.io/tiredofit/nginx-php-fpm:${PHP_VERSION}-${DISTRO} as grommunio-sync-builder
LABEL maintainer="Dave Conroy (github.com/tiredofit)"

ARG GROMMUNIO_SYNC_VERSION

ENV GROMMUNIO_SYNC_VERSION=${GROMMUNIO_SYNC_VERSION:-"fa3fdd253ccc892fda95c382d08edecf736217a5"} \
    GROMMUNIO_SYNC_REPO_URL=${GROMMUNIO_SYNC_REPO_URL:-"https://github.com/grommunio/grommunio-sync.git"} \
    PHP_ENABLE_GETTEXT=TRUE \
    PHP_ENABLE_MBSTRING=TRUE \
    PHP_ENABLE_XML=TRUE \
    PHP_ENABLE_ZIP=TRUE

COPY build-assets/ /build-assets

RUN source /assets/functions/00-container && \
    set -ex && \
    apk update && \
    apk upgrade && \
    apk add -t .grommunio-sync-build-deps \
                        git \
                        && \
    \
    ### Fetch Source
    clone_git_repo ${GROMMUNIO_SYNC_REPO_URL} ${GROMMUNIO_SYNC_VERSION} && \
    \
    set +e && \
    if [ -d "/build-assets/src" ] ; then cp -Rp /build-assets/src/* /usr/src/grommunio-web ; fi; \
    if [ -d "/build-assets/scripts" ] ; then for script in /build-assets/scripts/*.sh; do echo "** Applying $script"; bash $script; done && \ ; fi ; \
    set -e && \
    \
    ### Setup RootFS
    mkdir -p /rootfs/assets/.changelogs && \
    mkdir -p /rootfs/www/grommunio-sync && \
    mkdir -p /rootfs/assets/grommunio/config/sync && \
    \
    ### Move files to RootFS
    cp -Rp * /rootfs/www/grommunio-sync/ && \
    rm -rf /rootfs/www/grommunio-sync/build && \
    rm -rf /rootfs/www/grommunio-sync/grommunio-sync-top && \
    mv config.php /rootfs/assets/grommunio/config/sync/ && \
    ln -sf /etc/grommunio/sync.php config.php && \
    \
    chown -R ${NGINX_USER}:${NGINX_GROUP} /rootfs/www/grommunio-sync && \
    \
    ### Cleanup and Compress Package
    echo "Gromunio Sync ${GROMMUNIO_SYNC_VERSION} built from ${GROMMUNIO_SYNC_REPO_URL} on $(date +'%Y-%m-%d %H:%M:%S')" > /rootfs/assets/.changelogs/grommunio-sync.version && \
    echo "Commit: $(cd /usr/src/grommunio-dav ; echo $(git rev-parse HEAD))" >> /rootfs/assets/.changelogs/grommunio-sync.version && \
    env | grep ^GROMMUNIO | sort >> /rootfs/assets/.changelogs/grommunio-sync.version && \
    cd /rootfs/ && \
    find . -name .git -type d -print0|xargs -0 rm -rf -- && \
    mkdir -p /grommunio-sync/ && \
    tar cavf /grommunio-sync/grommunio-sync.tar.zst . &&\
    \
    ### Cleanup
    apk del .grommunio-sync-build-deps && \
    rm -rf /usr/src/* /var/cache/apk/*

FROM scratch
LABEL maintainer="Dave Conroy (github.com/tiredofit)"

COPY --from=grommunio-sync-builder /grommunio-sync/* /grommunio-sync/
COPY CHANGELOG.md /tiredofit_docker-grommunio-sync.md
