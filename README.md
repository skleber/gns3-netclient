# GNS3 Network Client Appliance

Lightweight Alpine-based Docker image optimized for **GNS3 network topology simulations, protocol analysis, and classroom teaching**. Provides a clean, modern interactive terminal equipped with standard network diagnostic tools, Python 3, and Java runtime, with 2 network interfaces by default.

> **Repository**: [https://github.com/skleber/gns3-netclient](https://github.com/skleber/gns3-netclient)  
> **Author & Maintainer**: Stephan Kleber  
> **License**: [GNU General Public License v3.0 (GPLv3)](LICENCE)  
> **Branches**: `master` (Alpine-based, ~349 MB) &bull; [`debian-full`](https://github.com/skleber/gns3-netclient/tree/debian-full) (Debian Bookworm, ~554 MB)

---

## Key Features

* **Beautiful Interactive Terminal**:
  * 256-color support with custom colored prompt (`netclient:\w# `)
  * Full programmable **Bash auto-completion** for commands, arguments, hostnames, and IP tools
  * Colorized aliases pre-configured (`ls --color=auto`, `grep --color=auto`, `ip -color=auto`)
  * Informational welcome banner displaying active interface IPs, gateway, and DNS configuration
  * Resilient shell session (exiting the shell respawns without terminating the GNS3 node)
* **Essential Network Analysis Toolset**:
  * `netcat-openbsd` (`nc`): Port scanning, TCP/UDP client/listener, banner grabbing
  * `ping` (`iputils`): ICMP echo requests and latency measurement
  * `host` & `dig` (`bind-tools`): Modern DNS inspection, zone transfer testing, record lookups
  * `tcpdump`: Real-time packet sniffing and capture
  * `iproute2` (`ip`, `ss`): Modern routing and socket inspection
  * `ifupdown-ng`: Native `/etc/network/interfaces` support for GNS3 "Edit config"
  * `curl`: HTTP/HTTPS protocol requests and API inspection
  * `nano`, `less`: Interactive file editing and paging
* **Language Runtimes Pre-installed**:
  * `python3`: Interactive Python interpreter for socket scripting and automation
  * `java` / `openjdk` (`openjdk17-jre-headless`): Headless Java 17 runtime for client applications and utilities
* **Dual Network Interfaces by Default**:
  * Configured with **2 network adapters** (`eth0` and `eth1`) out of the box in the GNS3 appliance template
  * Ideal for multi-homed hosts, routing labs, firewall testing, or gateway topologies
* **Default Lab Network Interoperability**:
  * Pre-configured with zero-configuration defaults to automatically resolve against a local DNS server (`10.0.0.1`) when placed on the same lab network

---

## Default Lab Network Integration

The appliance defaults are coordinated for zero-configuration startup in standard demonstration and teaching lab topologies:

| Setting | `gns3-netclient` Default | Lab Topology Mapping |
|---|---|---|
| **`eth0` IP** | `10.0.0.100/24` | Default client host address (`client.lab.local`) |
| **DNS Resolver** | `10.0.0.1` | Points to the local lab DNS server (`ns.lab.local`) |
| **Search Domain** | `lab.local` | Default local domain |
| **Default Gateway** | `10.0.0.254` | Matches default router address (`router.lab.local`) |

When connected to the same Ethernet switch as a local DNS server (`10.0.0.1`), resolution and connectivity work **immediately without manual configuration**:

```bash
# Verify connectivity to DNS server
ping 10.0.0.1

# Query demo hosts
host www.lab.local
dig www.lab.local
dig mail.lab.local MX

# Run automated built-in DNS self-test
test-dns
```

---

## GNS3 Quickstart

### Method 1: Import via Appliance Template (Recommended)
1. In GNS3, go to **File** &rarr; **Import appliance**.
2. Select [`gns3-netclient.gns3a`](gns3-netclient.gns3a).
3. The **Network Client** appliance will appear under your **End devices / Guests** palette with **2 network interfaces** and a desktop computer icon.
4. Drag it into your topology, connect `eth0` (and optionally `eth1`), and start the node.

### Method 2: Pull or Build Manually with Docker
To pull the pre-built multi-arch image:
```bash
docker pull ghcr.io/skleber/gns3-netclient:latest
```

To build locally from source:
```bash
docker build -t ghcr.io/skleber/gns3-netclient:latest .
```

---

## Network Configuration

The appliance supports **both** standard configuration methods:

### Method A: GNS3 Stock "Edit config" (Recommended)

Right-click the node in GNS3 &rarr; **Edit config**. This opens the standard `/etc/network/interfaces` file in GNS3's built-in editor:

```ini
# /etc/network/interfaces
auto lo
iface lo inet loopback

# eth0: Pre-configured default lab IP and DNS (10.0.0.1)
auto eth0
iface eth0 inet static
    address 10.0.0.100
    netmask 255.255.255.0
    gateway 10.0.0.254
    dns-nameservers 10.0.0.1
    dns-search lab.local
    up echo nameserver 10.0.0.1 > /etc/resolv.conf
    up echo search lab.local >> /etc/resolv.conf

# To use DHCP on eth0 instead:
# auto eth0
# iface eth0 inet dhcp

# eth1: Second network adapter (uncomment as needed)
# auto eth1
# iface eth1 inet dhcp
```

When the node boots, the configuration is automatically applied. Both standard Debian-style `dns-nameservers`/`dns-search` directives and `up echo ...` hooks are supported for DNS configuration. The startup splash screen dynamically reflects active IP assignments, active default gateway from the routing table, and active DNS resolvers from `/etc/resolv.conf`.

### Method B: Environment Variables (Alternative / Headless)

If you prefer configuring nodes headlessly or via Docker parameters without editing files:

| Variable | Default | Description |
|---|---|---|
| `IP_ETH0` | `10.0.0.100/24` | IPv4/CIDR address for `eth0`. Set to `dhcp` for DHCP client, or `none` for manual config. |
| `IP_ETH1` | `none` | IPv4/CIDR address for `eth1`. Set to `dhcp`, an IP/CIDR (e.g. `10.0.1.100/24`), or `none`. |
| `GATEWAY` | `10.0.0.254` | Default gateway IPv4 address. Set to `none` to disable default route. |
| `DNS` | `10.0.0.1` | Nameserver IP(s) for `/etc/resolv.conf`. Multiple servers separated by commas or spaces. |
| `SEARCH_DOMAIN` | `lab.local` | DNS search domain added to `/etc/resolv.conf`. |
| `HOSTNAME` | `netclient` | Hostname displayed in prompt and system banner. |
| `WAIT_LINK` | `0` | Set to `1` or `yes` to wait 2 seconds for GNS3 virtual links to establish before assigning IPs. |

---

## Built-in Helper Commands

In addition to standard Linux commands, two helper scripts are installed in `/usr/local/bin`:

### `net-status`
Displays a colorized summary of:
* Network interfaces, MAC addresses, and assigned IP addresses (`ip -br addr`)
* Kernel routing table (`ip route`)
* Configured DNS resolvers (`/etc/resolv.conf`)
* Active listening TCP/UDP sockets (`ss -tuln`)

```bash
netclient:~# net-status
```

### `test-dns [domain]`
Performs diagnostic DNS queries against the configured nameserver using both `dig` and `host`. If no domain is provided, it defaults to the configured search domain (e.g. `www.lab.local`).

```bash
netclient:~# test-dns
netclient:~# test-dns mail.lab.local
```

---

## Automated Integration Testing

An automated test script [`test-integration.sh`](test-integration.sh) is provided to verify all tools and end-to-end network interoperability with a local DNS server. It creates an isolated Docker test network, launches a test DNS server alongside `gns3-netclient`, and verifies ping, netcat port scanning, `dig`, `host`, Python socket lookups, OpenJDK runtime, packet capture, and DNS server query logs:

```bash
./test-integration.sh
```

---

## Example Network Topologies

### Scenario A: Simple Client-Server Lab
```
[ DNS Server ] (eth0: 10.0.0.1/24)
      |
  [ Switch ]
      |
[ gns3-netclient ] (eth0: 10.0.0.100/24, DNS: 10.0.0.1)
```

### Scenario B: Multi-Homed Host (2 Interfaces)
Via GNS3 **Edit config** (`/etc/network/interfaces`):
```ini
auto eth0
iface eth0 inet static
    address 192.168.1.50
    netmask 255.255.255.0
    gateway 192.168.1.1
    up echo nameserver 10.0.0.1 > /etc/resolv.conf

auto eth1
iface eth1 inet static
    address 10.0.0.50
    netmask 255.255.255.0
```
*(Or via environment variables: `IP_ETH0=192.168.1.50/24`, `IP_ETH1=10.0.0.50/24`, `GATEWAY=192.168.1.1`, `DNS=10.0.0.1`)*

```
[ Management LAN ]            [ Lab Network ]
        |                           |
     (eth0)                      (eth1)
     +-------------------------------+
     |       gns3-netclient          |
     +-------------------------------+
```

### Scenario C: Dynamic Host Configuration (DHCP)
Via GNS3 **Edit config** (`/etc/network/interfaces`):
```ini
auto eth0
iface eth0 inet dhcp
```
*(Or via environment variables: `IP_ETH0=dhcp`)*

The node automatically invokes `dhclient` on startup to acquire an IP address, gateway route, and DNS resolvers from a network DHCP server.

---

## Authors & License

* **Author & Maintainer**: Stephan Kleber (Copyright (C) 2026) &mdash; [skleber/gns3-netclient](https://github.com/skleber/gns3-netclient)

This program is free software: you can redistribute it and/or modify it under the terms of the [GNU General Public License v3.0 (GPLv3)](LICENCE) as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
