# Copyright (C) 2026 Stephan Kleber. All Rights Reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

FROM alpine:latest

LABEL org.opencontainers.image.title="GNS3 Network Client Appliance" \
      org.opencontainers.image.description="Lightweight Alpine-based Linux network client for GNS3 network analysis, teaching labs, and simulations" \
      org.opencontainers.image.url="https://github.com/skleber/gns3-netclient" \
      org.opencontainers.image.source="https://github.com/skleber/gns3-netclient" \
      org.opencontainers.image.licenses="GPL-3.0-or-later"

ENV SHELL=/bin/bash \
    TERM=xterm-256color

# Install required networking tools, runtimes, and shell utilities
RUN apk add --no-cache \
    bash \
    bash-completion \
    netcat-openbsd \
    iputils \
    bind-tools \
    tcpdump \
    python3 \
    openjdk17-jre-headless \
    iproute2 \
    ifupdown-ng \
    curl \
    nano \
    less \
    ca-certificates

# Configure terminal environment and completion
COPY etc/bash.bashrc /etc/bash/bashrc
RUN mkdir -p /etc/bash \
    && ln -sf /etc/bash/bashrc /etc/bash.bashrc \
    && echo "source /etc/bash/bashrc" >> /root/.bashrc

# Default network configuration (GNS3 Edit config template)
COPY etc/network/interfaces /etc/network/interfaces

# Install helper tools and startup script
COPY bin/ /usr/local/bin/
RUN chmod +x /usr/local/bin/* 2>/dev/null || true

COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

WORKDIR /root

CMD ["/startup.sh"]
