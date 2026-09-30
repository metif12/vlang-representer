FROM debian:bookworm-slim

# The V version is pinned, and deliberately so.
#
# `v fmt` is the whole normalization this representer performs, so the compiler
# is part of the representer's contract: if it were allowed to float, a new V
# release would change the representation of every solution already stored on
# the website, and mentor comments would silently stop matching.
#
# Bump V_VERSION and V_SHA256 together, and review the diff of
# tests/*/expected_representation.txt in the same PR.
ARG V_VERSION=0.5.2
ARG V_SHA256=86caf9e70c3342d48ef19eb4f6c47b709f18c90ae86255520d5c29df6b482e23

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl unzip tcc libc6-dev \
    && curl -fsSL -o /tmp/v.zip \
       "https://github.com/vlang/v/releases/download/${V_VERSION}/v_linux.zip" \
    && echo "${V_SHA256}  /tmp/v.zip" | sha256sum -c - \
    # The archive unpacks to a single v/ directory holding the binary and vlib.
    # V finds its standard library relative to the binary, so both must move
    # together.
    && unzip -q /tmp/v.zip -d /opt \
    && chmod +x /opt/v/v \
    && rm -f /tmp/v.zip \
    && apt-get purge -y --auto-remove curl unzip \
    && rm -rf /var/lib/apt/lists/*

# `v fmt` is not purely parser-based: it compiles cmd/tools/vfmt.v to a native
# binary on first use, so a C compiler has to exist in the image. tcc is a few
# hundred kilobytes against tens of megabytes for build-essential, and V prefers
# it anyway. Without this the representer fails on every run.
ENV CC=tcc

ENV VROOT=/opt/v
ENV V_BIN=/opt/v/v
ENV V_VERSION=${V_VERSION}

# Fail the build, not production, if the pinned version is not what we think, or
# if vfmt cannot be built. This second check is the one that matters: a V release
# that cannot format is a representer that cannot represent.
RUN "$V_BIN" version | grep -q "^V ${V_VERSION} " \
    && printf 'module main\n\nfn main() {}\n' > /tmp/probe.v \
    && "$V_BIN" fmt /tmp/probe.v | grep -q 'fn main'

# jq reads the exercise's .meta/config.json, because a solution's filename
# cannot always be derived from the slug (secret-handshake's is
# secret_handshake.v). bin/run.sh falls back to globbing if jq is unavailable,
# and sorts the result so both paths agree -- bin/run-tests.sh verifies this by
# running the fixtures here, with jq present, against expectations generated
# without it.
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/representer
COPY . .

ENTRYPOINT ["/opt/representer/bin/run.sh"]
