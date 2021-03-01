# ------------------------------------------------------------------------------
# Builder
# ------------------------------------------------------------------------------
FROM ubuntu:20.04 as builder

ENV DEBIAN_FRONTEND noninteractive
ENV REPO            https://github.com/h2o/h2o.git
ENV BRANCH          v2.3.0-beta2

# using Dockerfile.ubuntu1904 as reference
# see https://github.com/h2o/h2o/blob/master/misc/docker-ci/Dockerfile.ubuntu1904
RUN apt-get update -y \
    && apt-get install -y \
    	apache2-utils \
	bison \
	clang \
	cmake \
	cmake-data \
	curl \
	flex \
	git \
	libbrotli-dev \
	libc-ares-dev \
	libclang-dev \
	libedit-dev \
	libelf-dev \
	libev-dev \
	libssl-dev \
	libuv1-dev \
	llvm-dev \
	libllvm7 \
	llvm-7-dev \
	libclang-7-dev \
	zlib1g-dev \
	memcached \
	netcat-openbsd \
	nghttp2-client \
	php-cgi \
	pkgconf \
	python3 \
	python3-distutils \
	redis-server \
	ruby-dev \
	sudo \
	systemtap-sdt-dev \
	wget

RUN git clone --depth 1 $REPO -b $BRANCH /usr/local/src/h2o

WORKDIR /usr/local/src/h2o

COPY . /app

RUN cmake \
        -DWITH_BUNDLED_SSL=on \
        -DWITH_MRUBY=on \
        -DMRUBY_ADDITIONAL_CONFIG=/app/.h2o/mruby_additional_config.rb . \
    && make -j$(nproc) install

# ------------------------------------------------------------------------------
# Executor
# ------------------------------------------------------------------------------
FROM ubuntu:20.04

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends openssl \
    && apt-get clean -y \
    && rm -r -f /var/lib/apt/lists/*

RUN groupadd h2o \
    && useradd -d /home/h2o -g h2o h2o

USER h2o

# copy artifacts
COPY --from=builder /usr/local/bin/h2o            /usr/local/bin/h2o
COPY --from=builder /usr/local/bin/h2o-httpclient /usr/local/bin/h2o-httpclient
COPY --from=builder /usr/local/share/h2o          /usr/local/share/h2o

# copy config
COPY --from=builder /app/.h2o /home/h2o

EXPOSE 80 8080

CMD ["/bin/sh", "-c", "h2o -c /home/h2o/h2o.conf"]
