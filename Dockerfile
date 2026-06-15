# Stage 1: Build the toolchain
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    subversion \
    bison \
    flex \
    libboost-dev \
    zlib1g-dev \
    git \
    texinfo \
    pkg-config \
    libusb-1.0-0-dev \
    perl \
    autoconf \
    automake \
    help2man \
    python3 \
    python3-pip \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY Makefile .

# Build toolchain directly to its final install path so that any prefix-baked
# paths in SDCC/binutils binaries remain valid in the final image.
RUN make toolchain TOOLCHAIN_DIR=/opt/stm8-toolchain

# Remove the large build artefacts (sources, object files, etc.)
RUN make clean_toolchain TOOLCHAIN_DIR=/opt/stm8-toolchain

# SDCC trunk ships a unified linker as 'sdld' but still invokes it as 'sdldstm8'
RUN ln -s /opt/stm8-toolchain/bin/sdld /opt/stm8-toolchain/bin/sdldstm8

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Lean runtime image
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Runtime-only dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    make \
    python3 \
    libusb-1.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/stm8-toolchain /opt/stm8-toolchain

# Entrypoint script sources env.sh so PATH and PYTHONPATH are set for every
# invocation (env.sh uses a glob to find stm8dce's site-packages dir).
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Projects mount their source here
WORKDIR /project

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["bash"]
