#!/bin/bash

cat > /etc/openvpn/client/killswitch-off.sh << 'EOF'
#!/bin/bash
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo "Killswitch disabled"
EOF

chmod +x /etc/openvpn/client/killswitch-off.sh

echo -e "${GREEN}    [*] killswitch-off.sh script ready${NC}"
