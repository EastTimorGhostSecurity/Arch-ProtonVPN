#!/bin/bash

mkdir -p /etc/systemd/system/openvpn-client@$VPN_NAME.service.d

cat > /etc/systemd/system/openvpn-client@$VPN_NAME.service.d/override.conf << 'EOF'
[Service]
ExecStartPre=/etc/openvpn/client/killswitch.sh
ExecStopPost=/etc/openvpn/client/killswitch-off.sh
EOF

systemctl daemon-reload

echo -e "${GREEN}    [*] systemd override ready - killswitch automatic on start/stop${NC}"
