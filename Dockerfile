FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS build

# Fail the whole pipeline on the first failure. Alpine's /bin/sh is busybox
# ash, which is why the shell is named explicitly rather than left to sh.
SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# The version and the checksum of the release tarball. Both move together: a
# bump that changes only the version fails the build at the sha256sum check,
# which is the direction that failure should go, and the error names the
# expected and actual digests.
#
# Upstream vendored snapraid as a git submodule pinned to whatever commit was
# checked in — no tag, no release, nothing that said which version the image
# contained, and nothing Renovate could see.
# renovate: datasource=github-releases depName=amadvance/snapraid
ARG SNAPRAID_VERSION=14.9
ARG SNAPRAID_SHA256=40c216979d9d9853248060497341f74feaa07c8ae15927b6b14972c4f9d143d5

# add an unprivileged user without a shell and remove the rest
RUN adduser -s /bin/true -u 1000 -D -h /snapraid app \
  && sed -i -r "/^(app|root|nobody)/!d" /etc/group \
  && sed -i -r "/^(app|root|nobody)/!d" /etc/passwd \
  && sed -i -r 's#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd

# install the necessary build tools
# hadolint ignore=DL3018
RUN apk upgrade --no-cache \
  && apk add --no-cache build-base make autoconf automake coreutils curl

WORKDIR /src

# Fetch the release over HTTPS and verify it before unpacking anything.
RUN curl -fsSLO "https://github.com/amadvance/snapraid/releases/download/v${SNAPRAID_VERSION}/snapraid-${SNAPRAID_VERSION}.tar.gz" \
    && echo "${SNAPRAID_SHA256}  snapraid-${SNAPRAID_VERSION}.tar.gz" | sha256sum -c - \
    && tar -xzf "snapraid-${SNAPRAID_VERSION}.tar.gz" --strip-components=1 \
    && rm "snapraid-${SNAPRAID_VERSION}.tar.gz"

# Statically link, so the binary needs nothing at all in the final image.
RUN CFLAGS="-O2" LDFLAGS="-static" ./configure --prefix=/compiled \
    && make -j"$(nproc)" \
    && make install \
    && /compiled/bin/snapraid --version

#
# ---
#

FROM scratch

LABEL org.opencontainers.image.source="https://github.com/irondragonservices/iron-snapraid"
LABEL org.opencontainers.image.description="Hardened base image for running SnapRAID"

# add-in our unprivileged user
COPY --from=build /etc/passwd /etc/group /etc/shadow /etc/

# copy-in our snapraid binary
COPY --from=build /compiled/bin/snapraid /snapraid

USER app

# snapraid reads its configuration from a file that has to be mounted in, and
# writes its parity and content files to the arrays it is pointed at. Neither
# can be baked into an image.
ENTRYPOINT ["/snapraid"]
CMD ["--conf", "/etc/snapraid.conf", "--verbose", "status"]
