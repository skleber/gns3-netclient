#!/bin/bash
# Copyright (C) 2026 Stephan Kleber. All Rights Reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Integration test script for gns3-netclient and gns3-bind
set -e

# Cleanup any previous test artifacts
docker rm -f test-bind >/dev/null 2>&1 || true
docker network rm labnet >/dev/null 2>&1 || true

echo "=== [Step 1] Creating isolated lab network (10.0.0.0/24) ==="
docker network create --subnet=10.0.0.0/24 --gateway=10.0.0.254 labnet

echo "=== [Step 2] Starting gns3-bind on 10.0.0.1 ==="
docker run -d --name test-bind --net labnet --ip 10.0.0.1 \
  -e QUERY_LOG=yes \
  -e AUTHORITATIVE=self \
  -e 'DOMAIN_lab_local=@,A,10.0.0.1 ns,A,10.0.0.1 www,A,10.0.0.10 mail,A,10.0.0.20 client,A,10.0.0.100 @,MX,10,mail.lab.local.' \
  gns3-bind:latest

sleep 2

echo "=== [Step 3] Running integration tests from gns3-netclient (10.0.0.100) ==="
docker run --rm --net labnet --ip 10.0.0.100 \
  --dns 10.0.0.1 \
  --dns-search lab.local \
  -e DNS=10.0.0.1 \
  -e SEARCH_DOMAIN=lab.local \
  gns3-netclient:latest bash -c '
    echo "--- Test A: Ping BIND server (10.0.0.1) ---"
    ping -c 2 10.0.0.1

    echo -e "\n--- Test B: UDP Port scan BIND server port 53 with nc ---"
    nc -z -v -u -w 2 10.0.0.1 53

    echo -e "\n--- Test C: dig query for www.lab.local ---"
    dig @10.0.0.1 www.lab.local +short

    echo -e "\n--- Test D: dig query for MX records ---"
    dig @10.0.0.1 lab.local MX +short

    echo -e "\n--- Test E: host lookup for www.lab.local ---"
    host www.lab.local 10.0.0.1

    echo -e "\n--- Test F: Python socket resolution for www.lab.local ---"
    python3 -c "import socket; print(\"Resolved address:\", socket.gethostbyname(\"www.lab.local\"))"

    echo -e "\n--- Test G: Java OpenJDK headless execution ---"
    java -version

    echo -e "\n--- Test H: tcpdump packet capture test ---"
    tcpdump --version | head -n 1

    echo -e "\n--- Test I: Built-in test-dns helper tool ---"
    test-dns www.lab.local
'

echo "=== [Step 4] Checking gns3-bind query log ==="
docker logs test-bind | tail -n 12

echo "=== [Step 5] Cleaning up test containers & network ==="
docker rm -f test-bind >/dev/null
docker network rm labnet >/dev/null

echo "=== [SUCCESS] All integration tests passed! ==="
