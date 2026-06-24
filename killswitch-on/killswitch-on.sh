#!/bin/bash

# Build killswitch
cat > /etc/openvpn/client/killswitch.sh << 'EOF'
#!/bin/bash
# KILLSWITCH PROTONVPN - iptables

iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# ONLY THROUGH TUN0
iptables -A OUTPUT -o tun0 -j ACCEPT

EOF

# Add all remote IP + port
for ip in $REMOTE_IPS; do
    for port in $REMOTE_PORTS; do
        echo "iptables -A OUTPUT -d $ip -p udp --dport $port -j ACCEPT" >> /etc/openvpn/client/killswitch.sh
        echo "iptables -A OUTPUT -d $ip -p tcp --dport $port -j ACCEPT" >> /etc/openvpn/client/killswitch.sh
    done
done

cat >> /etc/openvpn/client/killswitch.sh << 'EOF'

# ICMP through tun0
iptables -A OUTPUT -o tun0 -p icmp -j ACCEPT

echo "Killswitch active"
EOF

chmod +x /etc/openvpn/client/killswitch.sh

# Apply killswitch
/etc/openvpn/client/killswitch.sh

echo -e "${GREEN}    [*] Killswitch script ready and applied${NC}"
