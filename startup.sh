#!/bin/bash
# Copyright (C) 2026 Stephan Kleber. All Rights Reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GNS3 Network Client Appliance Startup Script

set -e

# Configuration defaults - designed for zero-config operation out of the box in standard lab subnets
CLIENT_HOSTNAME="${HOSTNAME:-netclient}"
IP_ETH0="${IP_ETH0:-10.0.0.100/24}"
IP_ETH1="${IP_ETH1:-none}"
GATEWAY="${GATEWAY:-10.0.0.254}"
DNS="${DNS:-10.0.0.1}"
SEARCH_DOMAIN="${SEARCH_DOMAIN:-lab.local}"
WAIT_LINK="${WAIT_LINK:-0}"

# Optional link settling delay
if [ "$WAIT_LINK" = "1" ] || [ "$WAIT_LINK" = "yes" ]; then
    sleep 2
fi

# Set hostname
hostname "$CLIENT_HOSTNAME" 2>/dev/null || true
if ! grep -q "$CLIENT_HOSTNAME" /etc/hosts 2>/dev/null; then
    echo "127.0.0.1 $CLIENT_HOSTNAME" >> /etc/hosts
fi

# Bring up loopback
if command -v ifup >/dev/null 2>&1; then
    ifup lo 2>/dev/null || ip link set lo up 2>/dev/null || true
else
    ip link set lo up 2>/dev/null || true
fi

# Network configuration
# Method 1: GNS3 Stock Network Configuration (/etc/network/interfaces)
IFUP_CONFIGURED=0
if [ -f /etc/network/interfaces ] && grep -E '^\s*(iface|auto)\s+eth' /etc/network/interfaces >/dev/null 2>&1; then
    echo "[*] Applying GNS3 network configuration from /etc/network/interfaces..."
    if command -v ifup >/dev/null 2>&1; then
        ifup -a 2>/dev/null || true
        IFUP_CONFIGURED=1
    fi

    # Parse dns-nameservers and dns-search if resolv.conf was not already populated
    if ! grep -q "nameserver" /etc/resolv.conf 2>/dev/null; then
        DNS_NS=$(grep -E '^\s*dns-nameservers' /etc/network/interfaces 2>/dev/null | awk '{$1=""; print $0}')
        DNS_SEARCH=$(grep -E '^\s*dns-search' /etc/network/interfaces 2>/dev/null | awk '{print $2}')
        if [ -n "$DNS_NS" ]; then
            {
                [ -n "$DNS_SEARCH" ] && echo "search $DNS_SEARCH"
                for ns in $DNS_NS; do
                    [ -n "$ns" ] && echo "nameserver $ns"
                done
            } > /etc/resolv.conf 2>/dev/null || true
        fi
    fi
fi

# Method 2: Environment variables (fallback or explicit override)
if [ "$IFUP_CONFIGURED" -eq 0 ]; then
    configure_interface() {
        local iface="$1"
        local cfg="$2"

        if [ ! -d "/sys/class/net/$iface" ]; then
            return 0
        fi

        ip link set "$iface" up 2>/dev/null || true

        case "$cfg" in
            dhcp|DHCP)
                echo "[*] Requesting DHCP lease on $iface..."
                if command -v dhclient >/dev/null 2>&1; then
                    dhclient -q -nw "$iface" 2>/dev/null || true
                elif command -v udhcpc >/dev/null 2>&1; then
                    udhcpc -b -i "$iface" 2>/dev/null || true
                fi
                ;;
            none|NONE|manual|MANUAL|"")
                ;;
            *)
                ip addr flush dev "$iface" 2>/dev/null || true
                ip addr add "$cfg" dev "$iface" 2>/dev/null || true
                ;;
        esac
    }

    IP_ETH0="${IP_ETH0:-10.0.0.100/24}"
    IP_ETH1="${IP_ETH1:-none}"
    GATEWAY="${GATEWAY:-10.0.0.254}"
    DNS="${DNS:-10.0.0.1}"
    SEARCH_DOMAIN="${SEARCH_DOMAIN:-lab.local}"

    configure_interface "eth0" "$IP_ETH0"
    configure_interface "eth1" "$IP_ETH1"

    if [ -n "$GATEWAY" ] && [ "$GATEWAY" != "none" ] && [ "$GATEWAY" != "NONE" ]; then
        ip route replace default via "$GATEWAY" 2>/dev/null || ip route add default via "$GATEWAY" 2>/dev/null || true
    fi

    if [ -n "$DNS" ] && [ "$DNS" != "none" ] && [ "$DNS" != "NONE" ]; then
        {
            [ -n "$SEARCH_DOMAIN" ] && echo "search $SEARCH_DOMAIN"
            for ns in $(echo "$DNS" | tr ',' ' '); do
                [ -n "$ns" ] && echo "nameserver $ns"
            done
        } > /etc/resolv.conf 2>/dev/null || true
    fi
fi

# Print startup banner
cat << "EOF"

  _   _      _      ____ _ _            _   
 | \ | | ___| |_   / ___| (_) ___ _ __ | |_ 
 |  \| |/ _ \ __| | |   | | |/ _ \ '_ \| __|
 | |\  |  __/ |_  | |___| | |  __/ | | | |_ 
 |_| \_|\___|\__|  \____|_|_|\___|_| |_|\__|

 GNS3 Network Client Appliance (Debian Bookworm)
========================================================================
EOF

echo " Interface eth0: $(ip -br addr show eth0 2>/dev/null | awk '{print $3}' || echo 'down/unconfigured')"
echo " Interface eth1: $(ip -br addr show eth1 2>/dev/null | awk '{print $3}' || echo 'down/unconfigured')"
echo " Default Gateway: ${GATEWAY:-none}"
echo " DNS Resolver:    ${DNS:-none} (search: ${SEARCH_DOMAIN:-none})"
echo ""
echo " Pre-installed Tools:"
echo "   * Connectivity:  ping, nc (netcat-bsd), curl"
echo "   * DNS Analysis:  dig, host, nslookup"
echo "   * Traffic/Pkt:   tcpdump, ip (iproute2)"
echo "   * Runtimes:      python3, java (openjdk)"
echo " Helper Commands:"
echo "   * net-status   - show detailed interfaces, routes, listening ports"
echo "   * test-dns     - test DNS resolution against configured resolver"
echo "========================================================================"
echo ""

# Keep container alive and spawn interactive shell on telnet/console connect
if [ -t 0 ]; then
    while true; do
        /bin/bash -i -l
        echo -e "\n[!] Interactive session ended. Press Enter to restart shell..."
        read -r _ || sleep 1
    done
else
    # Non-interactive mode (e.g. background daemon)
    tail -f /dev/null
fi
