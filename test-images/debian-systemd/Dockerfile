FROM ghcr.io/thin-edge/tedge-demo-main-systemd:latest

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        # Install with all recommended packages as this is simplier to maintain
        podman \
    && tedge config unset c8y.proxy.client.host \
    && tedge config unset mqtt.client.host \
    && tedge config unset http.client.host

RUN echo "tedge  ALL = (ALL) NOPASSWD: /usr/bin/container-cli, /usr/bin/podman, /usr/bin/docker, /usr/bin/log_provider" | tee /etc/sudoers.d/tedge-containers

COPY dist/*.deb /tmp/
RUN apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" --allow-downgrades -y /tmp/*.deb \
    && rm -f /tmp/*.deb
