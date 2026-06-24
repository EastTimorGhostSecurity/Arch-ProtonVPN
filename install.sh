#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
                  -`
                 .o+`
                `ooo/
               `+oooo:
              `+oooooo:
              -+oooooo+:
            `/:-:++oooo+:
           `/++++/+++++++:
          `/++++++++++++++:
         `/+++ooooooooooooo/`
        ./ooosssso++osssssso+`
       .oossssso-````/ossssss+`
      -osssssso.      :ssssssso.
     :osssssss/        osssso+++.
    /ossssssss/        +ssssooo/-
  `/ossssso+/:-        -:/+osssso+-
 `+sso+:-`                 `.-/+oso:
`++:.                           `-/+/
.`                                 `/
EOF
echo -e "${NC}"

echo -e "${BLUE}Proton Auto Install Arch Linux${NC}"
echo ""

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[✗] Error: Please run as root (sudo)${NC}" 
   exit 1
fi

echo ""
echo -e "${YELLOW}Enter the path to your .ovpn file:${NC}"
echo -e "Example:protonvpn.udp.ovpn"
read -p "Path: " OVPN_PATH

if [[ ! -f "$OVPN_PATH" ]]; then
    echo -e "${RED}[✗] Error: .ovpn file not found!${NC}"
    exit 1
fi

echo -e "${YELLOW}Enter the path to your auth.txt file:${NC}"
echo -e "Example:auth.txt"
read -p "Path: " AUTH_PATH

if [[ ! -f "$AUTH_PATH" ]]; then
    echo -e "${RED}[✗] Error: auth.txt file not found!${NC}"
    exit 1
fi

OVPN_FILE=$(basename "$OVPN_PATH")
VPN_NAME=$(echo "$OVPN_FILE" | sed 's/\.ovpn$//')

REMOTE_IPS=$(grep "^remote" "$OVPN_PATH" | awk '{print $2}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u)
REMOTE_PORTS=$(grep "^remote" "$OVPN_PATH" | awk '{print $3}' | sort -u)

export OVPN_PATH
export AUTH_PATH
export VPN_NAME
export REMOTE_IPS
export REMOTE_PORTS
export RED GREEN YELLOW BLUE NC

LIB_DIR="."

echo ""
echo -e "${GREEN}[*] INFORMATION${NC}"
echo -e "    VPN Name: ${YELLOW}$VPN_NAME${NC}"
echo -e "    Remote IPs: ${YELLOW}$REMOTE_IPS${NC}"
echo -e "    Remote Ports: ${YELLOW}$REMOTE_PORTS${NC}"
echo -e "    Scripts Directory: ${YELLOW}$LIB_DIR${NC}"
echo ""

run_script() {
    local script_name=$1
    local script_path="$LIB_DIR/$script_name/$script_name.sh"
    
    if [[ -f "$script_path" ]]; then
        echo -e "${BLUE}[*] Running $script_name...${NC}"
        bash "$script_path"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}    [✗] $script_name failed!${NC}"
            exit 1
        fi
    else
        echo -e "${RED}[✗] Script not found: $script_path${NC}"
        exit 1
    fi
}

echo ""
echo -e "${BLUE}[1] Cleaning old tun interfaces...${NC}"
for i in 0 1 2 3 4; do
    ip link delete tun$i 2>/dev/null
done
echo -e "${GREEN}    [*] Clean${NC}"

echo ""
echo -e "${BLUE}[2] Installing packages...${NC}"
pacman -Syu --noconfirm openvpn openresolv wget bind > /dev/null 2>&1
echo -e "${GREEN}    [*] Packages installed${NC}"

echo ""
echo -e "${BLUE}[3] Creating directory...${NC}"
mkdir -p /etc/openvpn/client
echo -e "${GREEN}    [*] Directory ready${NC}"

echo ""
echo -e "${BLUE}[4] Copying configuration files...${NC}"
cp -f "$OVPN_PATH" "/etc/openvpn/client/$VPN_NAME.conf"
echo -e "${GREEN}    [*] .ovpn file copied${NC}"

run_script "auth-setup"

run_script "update-resolv-conf"

echo ""
echo -e "${BLUE}[7] Editing configuration...${NC}"
CONF="/etc/openvpn/client/$VPN_NAME.conf"

sed -i 's/^dev tun$/dev tun0/' "$CONF"

if grep -q "^auth-user-pass$" "$CONF"; then
    sed -i 's/^auth-user-pass$/auth-user-pass \/etc\/openvpn\/client\/auth.txt/' "$CONF"
elif grep -q "^auth-user-pass /" "$CONF"; then
    sed -i 's|^auth-user-pass .*|auth-user-pass /etc/openvpn/client/auth.txt|' "$CONF"
else
    sed -i '/^remote-cert-tls server/a auth-user-pass /etc/openvpn/client/auth.txt' "$CONF"
fi

if ! grep -q "auth-nocache" "$CONF"; then
    sed -i '/auth-user-pass/a auth-nocache' "$CONF"
fi

sed -i 's/^up \/etc\/openvpn\/update-resolv-conf/#up \/etc\/openvpn\/update-resolv-conf/' "$CONF"
sed -i 's/^down \/etc\/openvpn\/update-resolv-conf/#down \/etc\/openvpn\/update-resolv-conf/' "$CONF"
sed -i 's/^#up \/etc\/openvpn\/update-resolv-conf/#up \/etc\/openvpn\/update-resolv-conf/' "$CONF"
sed -i 's/^#down \/etc\/openvpn\/update-resolv-conf/#down \/etc\/openvpn\/update-resolv-conf/' "$CONF"

if ! grep -q "keepalive" "$CONF"; then
    echo "keepalive 10 60" >> "$CONF"
fi

echo -e "${GREEN}    [*] Configuration complete${NC}"

echo ""
echo -e "${BLUE}[8] Resetting resolvconf...${NC}"
chattr -i /etc/resolv.conf 2>/dev/null
rm -f /etc/resolv.conf 2>/dev/null
resolvconf -u 2>/dev/null
systemctl restart systemd-resolved 2>/dev/null
echo -e "${GREEN}    [*] resolvconf reset${NC}"

echo ""
echo -e "${BLUE}[9] Enabling service...${NC}"
systemctl enable "openvpn-client@$VPN_NAME" > /dev/null 2>&1
echo -e "${GREEN}    [*] Service enabled${NC}"

echo ""
echo -e "${BLUE}[10] Starting VPN...${NC}"
systemctl restart "openvpn-client@$VPN_NAME"
sleep 10
echo -e "${GREEN}    [*] VPN started${NC}"

echo ""
echo -e "${BLUE}[11] Checking VPN status...${NC}"
if systemctl is-active --quiet "openvpn-client@$VPN_NAME"; then
    echo -e "${GREEN}    [*] VPN active${NC}"
else
    echo -e "${RED}    [✗] VPN failed to start!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}[12] Checking tun0 interface...${NC}"
if ip a | grep -q "tun0:.*UP"; then
    echo -e "${GREEN}    [*] tun0 UP${NC}"
else
    echo -e "${RED}    [✗] tun0 not UP!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}[13] Checking routing...${NC}"
if ip route show | grep -q "dev tun0"; then
    echo -e "${GREEN}    [*] Routing via tun0${NC}"
else
    echo -e "${RED}    [✗] Routing not via tun0!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}[14] Checking VPN gateway...${NC}"
if ping -c 3 -W 2 10.96.0.1 > /dev/null 2>&1; then
    echo -e "${GREEN}    [*] Gateway reachable${NC}"
else
    echo -e "${RED}    [✗] Gateway not responding!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}[15] Setting up DNS (ONLY 10.96.0.1)...${NC}"
chattr -i /etc/resolv.conf 2>/dev/null
rm -f /etc/resolv.conf
echo "nameserver 10.96.0.1" > /etc/resolv.conf
chattr +i /etc/resolv.conf 2>/dev/null
echo -e "${GREEN}    [*] resolv.conf locked - ONLY DNS 10.96.0.1${NC}"

echo ""
echo -e "${BLUE}[16] Checking DNS 10.96.0.1...${NC}"
if dig @10.96.0.1 google.com +short > /dev/null 2>&1; then
    echo -e "${GREEN}    [*] DNS 10.96.0.1 Working...${NC}"
else
    echo -e "${RED}    [✗] DNS 10.96.0.1 Not Working..!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}[17] Final DNS check...${NC}"
if ping -c 2 -W 3 google.com > /dev/null 2>&1; then
    echo -e "${GREEN}    [*] DNS working - internet connected${NC}"
else
    echo -e "${RED}    [✗] DNS failed!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}[18] Checking public IP...${NC}"
PUBLIC_IP=$(curl -s --max-time 10 ifconfig.me)
if [[ -n "$PUBLIC_IP" ]]; then
    echo -e "${GREEN}    [*] Public IP: $PUBLIC_IP${NC}"
else
    echo -e "${RED}    [✗] Failed to get public IP!${NC}"
    exit 1
fi

run_script "killswitch-on"

echo ""
echo -e "${BLUE}[20] Checking killswitch...${NC}"
if iptables -L OUTPUT -v -n 2>/dev/null | grep -q "tun0"; then
    echo -e "${GREEN}    [*] Killswitch active${NC}"
else
    echo -e "${RED}    [✗] Killswitch failed!${NC}"
    exit 1
fi

run_script "systemd-override"

echo ""
echo -e "${BLUE}[22] Final test...${NC}"
if ping -c 2 -W 3 google.com > /dev/null 2>&1; then
    echo -e "${GREEN}    [*] Internet is working (via VPN)${NC}"
else
    echo -e "${RED}    [✗] Internet is not working!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}[*] ALL CHECKS PASSED! INSTALLATION COMPLETE${NC}"
echo ""
echo -e "${BLUE}[*] FINAL STATUS${NC}"
echo -e "    VPN: ${YELLOW}$VPN_NAME${NC}"
echo -e "    Public IP: ${YELLOW}$PUBLIC_IP${NC}"
echo -e "    DNS: ${GREEN}10.96.0.1 (ONLY VPN DNS - locked)${NC}"
echo -e "    Killswitch: ${GREEN}ACTIVE${NC}"
echo -e "    Killswitch automatic: ${GREEN}ACTIVE (start/stop VPN)${NC}"
echo ""
echo -e "${BLUE}[*] COMMANDS${NC}"
echo -e "    Start VPN:  ${GREEN}sudo systemctl start openvpn-client@$VPN_NAME${NC}"
echo -e "    Stop VPN:   ${GREEN}sudo systemctl stop openvpn-client@$VPN_NAME${NC}"
echo -e "    Status:     ${GREEN}sudo systemctl status openvpn-client@$VPN_NAME${NC}"
echo -e "    Disable killswitch manually: ${GREEN}sudo /etc/openvpn/client/killswitch-off.sh${NC}"
echo ""
echo -e "${GREEN}[*] Killswitch will automatically ACTIVATE when VPN starts${NC}"
echo -e "${GREEN}[*] Killswitch will automatically DEACTIVATE when VPN stops${NC}"
