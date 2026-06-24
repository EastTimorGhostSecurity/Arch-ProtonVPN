#!/bin/bash

cat > /etc/openvpn/update-resolv-conf << 'EOF'
#!/bin/bash
# Script for Arch Linux - update resolv.conf via openresolv

case $script_type in
  up)
    if [ -n "$foreign_option_1" ]; then
      echo "Setting DNS from OpenVPN"
      for optionname in ${!foreign_option_*} ; do
        option="${!optionname}"
        if [[ "$option" =~ "dhcp-option DOMAIN" ]] ; then
          echo "domain ${option#dhcp-option DOMAIN }"
        elif [[ "$option" =~ "dhcp-option DNS" ]] ; then
          echo "nameserver ${option#dhcp-option DNS }"
        fi
      done | resolvconf -a tun.${dev}
    fi
    ;;
  down)
    resolvconf -d tun.${dev}
    ;;
esac
EOF

chmod +x /etc/openvpn/update-resolv-conf
echo -e "${GREEN}    [*] update-resolv-conf script ready${NC}"
