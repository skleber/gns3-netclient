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

FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="GNS3 Network Client Appliance" \
      org.opencontainers.image.description="Minimal Debian-based Linux network client for GNS3 network analysis, teaching labs, and simulations" \
      org.opencontainers.image.url="https://github.com/skleber/gns3-netclient" \
      org.opencontainers.image.source="https://github.com/skleber/gns3-netclient" \
      org.opencontainers.image.licenses="GPL-3.0-or-later"

# Prevent interactive prompts during apt install
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    TERM=xterm-256color

# Install required networking tools, runtimes, and shell utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    bash-completion \
    netcat-openbsd \
    iputils-ping \
    bind9-dnsutils \
    tcpdump \
    python3 \
    default-jre-headless \
    iproute2 \
    isc-dhcp-client \
    curl \
    nano \
    less \
    ca-certificates \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /usr/share/doc/* /usr/share/man/*

# Configure terminal environment and completion
COPY etc/bash.bashrc /etc/bash.bashrc
RUN echo "source /etc/bash.bashrc" >> /root/.bashrc

# Install helper tools and startup script
COPY bin/ /usr/local/bin/
RUN chmod +x /usr/local/bin/* 2>/dev/null || true

COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

WORKDIR /root

CMD ["/startup.sh"]
