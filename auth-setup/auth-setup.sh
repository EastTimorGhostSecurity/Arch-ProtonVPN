#!/bin/bash

cp -f "$AUTH_PATH" /etc/openvpn/client/auth.txt
chmod 600 /etc/openvpn/client/auth.txt

echo -e "${GREEN}    [*] auth.txt copied and permission set to 600${NC}"
