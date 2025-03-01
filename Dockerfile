FROM alpine:3.20

WORKDIR /var/www/html

ENV NGINX_VERSION=1.26.3
ENV MORE_SET_HEADER_VERSION=0.34
ENV FANCYINDEX=0.5.2
ENV MODULE_URL_BASE=https://nginx.org/packages/alpine/v3.20/main/x86_64/

RUN mkdir -p /var/www/html \
    && GPG_KEYS=D6786CE303D9A9022998DC6CC8464D549AF75C0A \
    && CONFIG="\
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_stub_status_module \
        --with-http_auth_request_module \
        --with-http_xslt_module=dynamic \
        --with-http_image_filter_module=dynamic \
        --with-http_geoip_module=dynamic \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-stream_realip_module \
        --with-stream_geoip_module=dynamic \
        --with-http_slice_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-compat \
        --with-file-aio \
        --with-http_v2_module \
        --add-module=/tmp/headers-more-nginx-module-$MORE_SET_HEADER_VERSION \
        --add-module=/tmp/ngx-fancyindex-$FANCYINDEX \
        --add-module=/tmp/ngx_http_substitutions_filter_module \
    " \
    && addgroup -S nginx \
    && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
    && apk add --no-cache --allow-untrusted --virtual .build-deps \
        git \
        gcc \
        libc-dev \
        make \
        openssl-dev \
        pcre-dev \
        zlib-dev \
        linux-headers \
        curl \
        gnupg \
        libxslt-dev \
        gd-dev \
        geoip-dev \
    && cd /tmp/ \
    && git clone https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git /tmp/ngx_http_substitutions_filter_module \
    && curl -sfSL https://github.com/openresty/headers-more-nginx-module/archive/v$MORE_SET_HEADER_VERSION.tar.gz -o $MORE_SET_HEADER_VERSION.tar.gz \
    && tar xvf $MORE_SET_HEADER_VERSION.tar.gz \
    && curl -sfSL https://github.com/aperezdc/ngx-fancyindex/releases/download/v$FANCYINDEX/ngx-fancyindex-$FANCYINDEX.tar.xz -o fancyindex.tar.xz \
    && tar xvf fancyindex.tar.xz \
    && curl -sfSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
    && curl -sfSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
    && export GNUPGHOME="$(mktemp -d)" \
    && found=''; \
    for server in \
        ha.pool.sks-keyservers.net \
        hkp://keyserver.ubuntu.com:80 \
        hkp://p80.pool.sks-keyservers.net:80 \
        pgp.mit.edu \
    ; do \
        echo "Fetching GPG key $GPG_KEYS from $server"; \
        gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
    gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
    && pkill -9 gpg-agent \
    && pkill -9 dirmngr \
    && rm -r "$GNUPGHOME" nginx.tar.gz.asc \
    && mkdir -p /usr/src \
    && tar -zxC /usr/src -f nginx.tar.gz \
    && rm nginx.tar.gz \
    && cd /usr/src/nginx-$NGINX_VERSION \
    && ./configure $CONFIG --with-debug \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && mv objs/nginx objs/nginx-debug \
    && mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
    && mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
    && mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
    && mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
    && ./configure $CONFIG \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && rm -rf /etc/nginx/html/ \
    && mkdir /etc/nginx/conf.d/ \
    && mkdir -p /usr/share/nginx/html/ \
    && install -m644 html/index.html /usr/share/nginx/html/ \
    && install -m644 html/50x.html /usr/share/nginx/html/ \
    && install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
    && install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
    && install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
    && install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
    && install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so \
    && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
    && strip /usr/sbin/nginx* \
    && strip /usr/lib/nginx/modules/*.so \
    && rm -rf /usr/src/nginx-$NGINX_VERSION \
    \
    # Bring in gettext so we can get `envsubst`, then throw
    # the rest away. To do this, we need to install `gettext`
    # then move `envsubst` out of the way so `gettext` can
    # be deleted completely, then move `envsubst` back.
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    \
    && runDeps="$( \
        scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache --virtual .nginx-rundeps $runDeps apache2-utils \
    c-ares \
    libstdc++ \
    curl \
    && apk del --no-cache .build-deps \
    && apk del --no-cache .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
    && rm /tmp/$MORE_SET_HEADER_VERSION.tar.gz \
    && rm -rf /tmp/headers-more-nginx-module-$MORE_SET_HEADER_VERSION \
    && rm /tmp/fancyindex.tar.xz \
    && rm -rf /tmp/ngx-fancyindex-$FANCYINDEX \
    && rm -rf /tmp/ngx_http_substitutions_filter_module \
    && rm -rf /tmp/pear \
    \
    # forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && cp /usr/share/nginx/html/* /var/www/html

# NGINX-UI integration
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG S6_OVERLAY_VERSION=3.1.6.2

ENV DEBIAN_FRONTEND=noninteractive
ENV NGINX_UI_OFFICIAL_DOCKER=true

RUN apt-get update -y \
    && apt install -y --no-install-recommends wget xz-utils logrotate nginx-module-geoip \
    && rm -rf /var/lib/apt/lists/*

# s6-overlay
RUN case "${TARGETARCH}/${TARGETVARIANT}" in \
        "amd64/"*) S6_ARCH="x86_64" ;; \
        "arm64/"*) S6_ARCH="aarch64" ;; \
        "arm/v7"*) S6_ARCH="arm" ;; \
        "arm/v6"*) S6_ARCH="arm" ;; \
        "arm/v5"*) S6_ARCH="arm" ;; \
        *) echo "Unsupported arch: ${TARGETARCH}/${TARGETVARIANT}" && exit 1 ;; \
    esac && \
    wget -O /tmp/s6-overlay-noarch.tar.xz https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    wget -O /tmp/s6-overlay-${S6_ARCH}.tar.xz https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-${S6_ARCH}.tar.xz && \
    wget -O /tmp/s6-overlay-noarch.tar.xz https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz

# register nginx service
COPY nginx-ui-base/nginx /etc/s6-overlay/s6-rc.d/nginx/run
RUN echo 'longrun' > /etc/s6-overlay/s6-rc.d/nginx/type && touch /etc/s6-overlay/s6-rc.d/user/contents.d/nginx

RUN mkdir -p /usr/local/etc \
    && mkdir /etc/nginx/sites-available \
    && mkdir /etc/nginx/sites-enabled \
    && mkdir /etc/nginx/streams-available \
    && mkdir /etc/nginx/streams-enabled \
    && cp -r /etc/nginx /usr/local/etc/nginx

# init config
COPY nginx-ui-base/init-config.up /etc/s6-overlay/s6-rc.d/init-config/up
COPY nginx-ui-base/init-config.sh /etc/s6-overlay/s6-rc.d/init-config/init-config.sh

RUN chmod +x /etc/s6-overlay/s6-rc.d/init-config/init-config.sh && \
    echo 'oneshot' > /etc/s6-overlay/s6-rc.d/init-config/type && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/init-config && \
    mkdir -p /etc/s6-overlay/s6-rc.d/nginx/dependencies.d && \
    touch /etc/s6-overlay/s6-rc.d/nginx/dependencies.d/init-config

# NGINX-UI specific setup
COPY resources/docker/nginx-ui.run /etc/s6-overlay/s6-rc.d/nginx-ui/run
RUN echo 'longrun' > /etc/s6-overlay/s6-rc.d/nginx-ui/type && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/nginx-ui

COPY resources/docker/nginx.conf /usr/local/etc/nginx/nginx.conf
COPY resources/docker/nginx-ui.conf /usr/local/etc/nginx/conf.d/nginx-ui.conf
COPY nginx-ui-$TARGETOS-$TARGETARCH$TARGETVARIANT/nginx-ui /usr/local/bin/nginx-ui

RUN rm -f /etc/nginx/conf.d/default.conf  \
    && rm -f /usr/local/etc/nginx/conf.d/default.conf

RUN rm -f /var/log/nginx/access.log && \
    touch /var/log/nginx/access.log && \
    rm -f /var/log/nginx/error.log && \
    touch /var/log/nginx/error.log

ENTRYPOINT ["/init"]

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/nginx.vh.default.conf /etc/nginx/conf.d/default.conf
RUN wget -qO- $MODULE_URL_BASE | \
    grep -o 'nginx-module-otel-[0-9\.]*-r[0-9]*\.apk' | \
    sort -Vr | \
    head -n 1 | \
    xargs -I {} wget ${MODULE_URL_BASE}{} && \
    tar -xzf ./nginx-module-otel-*.apk 
RUN install -m755 /var/www/html/usr/lib/nginx/modules/ngx_otel_module.so /etc/nginx/modules/ngx_otel_module.so && \
    rm nginx-module-otel-*.apk

EXPOSE 80 443
STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]
