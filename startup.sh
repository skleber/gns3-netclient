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

# Capture any user-specified overrides from environment
USER_GATEWAY="${GATEWAY:-}"
USER_DNS="${DNS:-}"
USER_SEARCH="${SEARCH_DOMAIN:-}"

CLIENT_HOSTNAME="${HOSTNAME:-netclient}"
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

    # Ensure default gateway from /etc/network/interfaces replaces any pre-existing route
    IFACE_GW=$(grep -E '^\s*gateway\s+' /etc/network/interfaces 2>/dev/null | awk '{print $2; exit}')
    if [ -n "$IFACE_GW" ]; then
        ip route replace default via "$IFACE_GW" 2>/dev/null || ip route add default via "$IFACE_GW" 2>/dev/null || true
    fi

    # Parse dns-nameservers and dns-search / dns-domain from /etc/network/interfaces
    DNS_NS=$(grep -E '^\s*dns-nameservers?' /etc/network/interfaces 2>/dev/null | awk '{$1=""; print $0}')
    DNS_SEARCH=$(grep -E '^\s*(dns-search|dns-domain)' /etc/network/interfaces 2>/dev/null | awk '{$1=""; sub(/^[ \t]+/, ""); print $0; exit}')
    if [ -n "$DNS_NS" ]; then
        {
            [ -n "$DNS_SEARCH" ] && echo "search $DNS_SEARCH"
            for ns in $DNS_NS; do
                [ -n "$ns" ] && echo "nameserver $ns"
            done
        } > /etc/resolv.conf 2>/dev/null || true
    elif [ -n "$USER_DNS" ]; then
        {
            [ -n "$USER_SEARCH" ] && echo "search $USER_SEARCH"
            for ns in $(echo "$USER_DNS" | tr ',' ' '); do
                [ -n "$ns" ] && echo "nameserver $ns"
            done
        } > /etc/resolv.conf 2>/dev/null || true
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
    GATEWAY="${USER_GATEWAY:-10.0.0.254}"
    DNS="${USER_DNS:-10.0.0.1}"
    SEARCH_DOMAIN="${USER_SEARCH:-lab.local}"

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

# Helper functions for banner network status display
get_iface_ip() {
    local iface="$1"
    if [ ! -d "/sys/class/net/$iface" ]; then
        echo "not present"
        return
    fi
    local addrs
    addrs=$(ip -br addr show "$iface" 2>/dev/null | awk '{
        out = ""
        for (i = 3; i <= NF; i++) {
            if ($i !~ /^fe80:/) {
                out = (out == "" ? $i : out ", " $i)
            }
        }
        print out
    }')
    if [ -n "$addrs" ]; then
        echo "$addrs"
    else
        echo "unconfigured"
    fi
}

get_default_gateway() {
    local gw
    gw=$(ip route show default 2>/dev/null | awk '{
        for (i = 1; i <= NF; i++) {
            if ($i == "via") {
                val = $(i+1)
                if (!seen[val]++) out = (out == "" ? val : out ", " val)
            }
        }
    } END { print out }')
    if [ -z "$gw" ]; then
        gw=$(ip route show default 2>/dev/null | awk '/default dev/ {print $3; exit}')
    fi
    echo "${gw:-none}"
}

get_dns_info() {
    local ns search_dom
    ns=$(grep -E '^\s*nameserver\s+' /etc/resolv.conf 2>/dev/null | awk '{printf "%s%s", (NR>1?", ":""), $2}')
    search_dom=$(grep -E '^\s*(search|domain)\s+' /etc/resolv.conf 2>/dev/null | awk '{$1=""; sub(/^[ \t]+/, ""); print $0; exit}')
    if [ -n "$ns" ]; then
        if [ -n "$search_dom" ]; then
            echo "$ns (search: $search_dom)"
        else
            echo "$ns"
        fi
    else
        echo "none"
    fi
}

# Print startup banner
cat << "EOF"

  _   _      _      ____ _ _            _   
 | \ | | ___| |_   / ___| (_) ___ _ __ | |_ 
 |  \| |/ _ \ __| | |   | | |/ _ \ '_ \| __|
 | |\  |  __/ |_  | |___| | |  __/ | | | |_ 
 |_| \_|\___|\__|  \____|_|_|\___|_| |_|\__|

 GNS3 Network Client Appliance (Alpine Linux)
========================================================================
EOF

# Display all eth interfaces (ensuring eth0 and eth1 are always listed)
eth_ifaces=$(ls -d /sys/class/net/eth* 2>/dev/null | xargs -n1 basename 2>/dev/null | sort -V || true)
[ -z "$eth_ifaces" ] && eth_ifaces="eth0 eth1"
if ! echo "$eth_ifaces" | grep -qw "eth1"; then
    eth_ifaces="$eth_ifaces eth1"
fi
for iface in $eth_ifaces; do
    echo " Interface ${iface}: $(get_iface_ip "$iface")"
done
echo " Default Gateway: $(get_default_gateway)"
echo " DNS Resolver:    $(get_dns_info)"
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
