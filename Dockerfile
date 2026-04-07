# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:edge AS buildstage

# build variables
ARG MINIFLUX_RELEASE

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache \
    build-base \
    go

RUN \
  echo "**** fetch source code ****" && \
  if [ -z ${MINIFLUX_RELEASE+x} ]; then \
    MINIFLUX_RELEASE=$(curl -sX GET "https://api.github.com/repos/miniflux/v2/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  mkdir -p \
    /tmp/miniflux && \
  curl -o \
  /tmp/miniflux-src.tar.gz -L \
    "https://github.com/miniflux/v2/archive/${MINIFLUX_RELEASE}.tar.gz" && \
  tar xf \
  /tmp/miniflux-src.tar.gz -C \
    /tmp/miniflux --strip-components=1 && \
  echo "**** compile miniflux  ****" && \
  cd /tmp/miniflux && \
  CGO_ENABLED=0 GOARCH=amd64 GOOS=linux go build \
    -ldflags "-s -w \
    -X miniflux.app/v2/internal/version.Version=${MINIFLUX_RELEASE} \
    -X miniflux.app/v2/internal/version.Commit=${VERSION} \
    -X miniflux.app/v2/internal/version.BuildDate=${BUILD_DATE}" \
    -o /app/miniflux

############## runtime stage ##############
FROM ghcr.io/linuxserver/baseimage-alpine:3.23

# set version label
ARG BUILD_DATE
ARG VERSION
ARG MINIFLUX_RELEASE
LABEL build_version="version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="justy777"

RUN \
  printf "version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version

# add miniflux
COPY --from=buildstage /app/miniflux /app/miniflux

# add local files
COPY /root /

# ports and volumes
EXPOSE 8080
VOLUME /config
