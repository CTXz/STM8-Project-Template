FROM eclipse-temurin:8-jre-jammy

ENV DEBIAN_FRONTEND=noninteractive

ARG STM8CUBEMX_ZIP

COPY ${STM8CUBEMX_ZIP} /tmp/stm8cubemx.zip
COPY docker/cube/stm8cubemx-auto-install.xml /tmp/stm8cubemx-auto-install.xml

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        dbus-x11 \
        file \
        fontconfig \
        fonts-dejavu-core \
        gosu \
        libc6:i386 \
        libasound2 \
        libfontconfig1 \
        libfreetype6 \
        libgl1 \
        libgtk2.0-0 \
        libx11-6 \
        libxcursor1 \
        libxext6 \
        libxfixes3 \
        libxi6 \
        libxinerama1 \
        libxrandr2 \
        libxrender1 \
        libxss1 \
        libxtst6 \
        unzip \
        xauth \
        xdg-utils \
    && mkdir -p /tmp/stm8cubemx-installer \
    && unzip -q /tmp/stm8cubemx.zip -d /tmp/stm8cubemx-installer \
    && stm8cubemx_installer="$(find /tmp/stm8cubemx-installer -maxdepth 1 -type f -name 'SetupSTM8CubeMX-*.exe' | sort -V | tail -n 1)" \
    && test -n "${stm8cubemx_installer}" \
    && java -jar "${stm8cubemx_installer}" /tmp/stm8cubemx-auto-install.xml \
    && ln -s /opt/st/stm8cubemx/STM8CubeMX /usr/local/bin/stm8cubemx \
    && chmod -R a+rX /opt/st/stm8cubemx \
    && rm -rf \
        /tmp/stm8cubemx.zip \
        /tmp/stm8cubemx-auto-install.xml \
        /tmp/stm8cubemx-installer \
        /var/lib/apt/lists/*

COPY docker/cube/entrypoint.sh /usr/local/bin/cube-entrypoint
RUN chmod +x /usr/local/bin/cube-entrypoint \
    && mkdir -p /tmp/wayland

WORKDIR /workspace

ENTRYPOINT ["cube-entrypoint"]
CMD ["bash"]
