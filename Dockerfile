FROM alpine:latest AS base

RUN apk update
RUN apk upgrade --no-cache

FROM base AS build

RUN apk add gcc
RUN apk add clang
RUN apk add musl-dev
RUN apk add binutils
RUN apk add nimble
RUN apk add git

RUN git clone --depth 1 --branch v0.3.1 https://github.com/GeeLeonidas/carlito /repo
WORKDIR /repo
RUN nimble refresh -y
RUN nimble build -d:release

FROM base AS final

RUN apk add --no-cache openssl-dev
RUN apk add --no-cache libsodium
RUN apk add --no-cache ffmpeg
RUN apk add --no-cache yt-dlp
RUN apk add --no-cache pcre
RUN apk add --no-cache curl
RUN apk add --no-cache opus

COPY --from=build /repo/bin/carlito /usr/bin
ENTRYPOINT [ "/usr/bin/carlito" ]