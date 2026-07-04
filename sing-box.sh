#!/bin/bash

declare -g SERVER_PUBLIC_IP="$(curl -s https://cloudflare.com/cdn-cgi/trace | grep ip | awk -F '=' '{ print $2 }')"

function distribution() {
    if [ ! -f "/etc/debian_version" ]; then
        echo "ERROR: Linux distribution must be Ubuntu!"
        exit 1
    fi
}

function root() {
    if [ "$(echo ${USER})" != "root" ]; then
        echo "WARNING: You must be root to run the script!"
        exit 1
    fi
}

function install() {
    local HOSTNAME="$(hostname)"

    if [ -f "/usr/bin/sing-box" ]; then
        echo "NOTICE: The sing-box binary file is installed, no need to reinstall!"
    else
        if [ "${HOSTNAME}" == "pikvm" ] || \
           [ "${HOSTNAME}" == "verizon" ] || \
           [ "${HOSTNAME}" == "at&t" ] || \
           [ "${HOSTNAME}" == "t-mobile" ] || \
           [ "${HOSTNAME}" == "cmcc" ] || \
           [ "${HOSTNAME}" == "aws" ] || \
           [ "${HOSTNAME}" == "us-west-1a" ] || \
           [ "${HOSTNAME}" == "us-west-2a" ] || \
           [ "${HOSTNAME}" == "us-west-2-wl1-sfo-wlz-1" ] || \
           [ "${HOSTNAME}" == "ap-east-1a" ] || \
           [ "${HOSTNAME}" == "tc" ]; then
            curl -fsSL https://sing-box.app/install.sh | sh -s -- --version 1.13.0 >/dev/null 2>&1
        else
            curl -fsSL https://sing-box.app/install.sh | sh -s -- --version 1.12.22 >/dev/null 2>&1
        fi
    fi
    exit 0
}

function generate_wireguard() {
    if [ ! -f "/usr/bin/sing-box" ]; then
        echo "WARNING: The sing-box binary file isn't installed!"
        exit 1
    fi

    if [ ! -f "/etc/wireguard/wg0.conf" ]; then
        echo "ERROR: No such a file!"
        echo "  - /etc/wireguard/wg0.conf"
        exit 1
    fi

    if [ ! -d "/etc/sing-box" ]; then
        mkdir /etc/sing-box
    fi

    if [[ "${SERVER_PUBLIC_IP}" == *":"* ]]; then
        wget -q https://raw.githubusercontent.com/sengshinlee/wg2sing-tun2socks5/refs/heads/main/user-custom-templates/wireguard/server/ubuntu/sing-tun2socks5/config.ipv4.json5 -P /etc/sing-box
        wget -q https://raw.githubusercontent.com/sengshinlee/wg2sing-tun2socks5/refs/heads/main/user-custom-templates/wireguard/server/ubuntu/sing-tun2socks5/config.json5 -P /etc/sing-box

        sed '10i PreUp = ip -4 rule add iif wg0 lookup 2022 priority 8990 >/dev/null 2>&1 || true\
PreUp = ip -6 rule add iif wg0 lookup 2022 priority 8990 >/dev/null 2>&1 || true\
PreUp = sing-box run -c /etc/sing-box/config.json5 & >/dev/null 2>&1' /etc/wireguard/wg0.conf | \
        tee /etc/wireguard/wg0.sing-box.conf >/dev/null 2>&1

        sed -i '33i PostDown = ip -4 rule del iif wg0 lookup 2022 priority 8990 >/dev/null 2>&1 || true\
PostDown = ip -6 rule del iif wg0 lookup 2022 priority 8990 >/dev/null 2>&1 || true\
PostDown = pkill -15 -f "sing-box run -c /etc/sing-box/config.json5"' /etc/wireguard/wg0.sing-box.conf >/dev/null 2>&1

        echo "WARNING:"
        echo ""
        echo -e "  When you use \"config.ipv4.json5\", you must rename it to \"config.json5\"."
        echo ""
    else
        wget -q https://raw.githubusercontent.com/sengshinlee/wg2sing-tun2socks5/refs/heads/main/user-custom-templates/wireguard/server/ubuntu/sing-tun2socks5/config.ipv4.json5 -O /etc/sing-box/config.json5

        sed '12i PreUp = ip -4 rule add iif wg0 lookup 2022 priority 8990 >/dev/null 2>&1 || true\
PreUp = sing-box run -c /etc/sing-box/config.json5 & >/dev/null 2>&1' /etc/wireguard/wg0.conf | \
        tee /etc/wireguard/wg0.sing-box.conf >/dev/null 2>&1

        sed -i '24i PostDown = ip -4 rule del iif wg0 lookup 2022 priority 8990 >/dev/null 2>&1 || true\
PostDown = pkill -15 -f "sing-box run -c /etc/sing-box/config.json5"' /etc/wireguard/wg0.sing-box.conf >/dev/null 2>&1
    fi

    sed -i 's/\bwg0\b/wg0.sing-box/g' /etc/wireguard/wg0.sing-box.conf >/dev/null 2>&1
    exit 0
}

function generate_tailscale() {
    if [ ! -f "/usr/bin/sing-box" ]; then
        echo "WARNING: The sing-box binary file isn't installed!"
        exit 1
    fi

    if [ ! -d "/etc/sing-box" ]; then
        mkdir -p /etc/sing-box
    fi

    if [[ "${SERVER_PUBLIC_IP}" == *":"* ]]; then
        wget -q https://raw.githubusercontent.com/sengshinlee/wg2sing-tun2socks5/refs/heads/main/user-custom-templates/tailscale/server/ubuntu/sing-tun2socks5/config.ipv4.json5 -P /etc/sing-box
        wget -q https://raw.githubusercontent.com/sengshinlee/wg2sing-tun2socks5/refs/heads/main/user-custom-templates/tailscale/server/ubuntu/sing-tun2socks5/config.json5 -P /etc/sing-box

        echo "WARNING:"
        echo ""
        echo -e "  When you use \"config.ipv4.json5\", you must rename it to \"config.json5\"."
        echo ""
    else
        wget -q https://raw.githubusercontent.com/sengshinlee/wg2sing-tun2socks5/refs/heads/main/user-custom-templates/tailscale/server/ubuntu/sing-tun2socks5/config.ipv4.json5 -O /etc/sing-box/config.json5
    fi
    exit 0
}

function remove() {
    if [ -f "/usr/bin/sing-box" ]; then
        rm /usr/local/bin/wg-quick-cron.sh >/dev/null 2>&1
        rm /var/log/wg-quick-cron.log >/dev/null 2>&1
        rm /usr/local/bin/sing-box-run-cron.sh >/dev/null 2>&1
        rm /var/log/sing-box-run-cron.log >/dev/null 2>&1
        rm /home/ubuntu/cache.db >/dev/null 2>&1

        wg-quick down wg0.sing-box >/dev/null 2>&1
        pkill -15 -f "sing-box run -c /etc/sing-box/config.json5" >/dev/null 2>&1
        apt-get purge sing-box -y >/dev/null 2>&1

        if [ -d "/etc/sing-box" ]; then
            rm -rf /etc/sing-box >/dev/null 2>&1
            rm /etc/wireguard/wg0.sing-box.conf >/dev/null 2>&1
        fi

        if [ -d "/etc/tailscale" ]; then
    	    rm -rf /etc/tailscale >/dev/null 2>&1
    	fi

        echo "NOTICE:"
        echo "  - Remove your cron schedule?"
        echo ""
        echo "      crontab -e"
        echo ""
    else
        echo "NOTICE: Not installed, no need to remove!"
    fi
    exit 0
}

function wg_quick_cron() {
    cat >/usr/local/bin/wg-quick-cron.sh <<'EOF'
#!/bin/bash

# SERVER_WG_NIC="wg0"
SERVER_WG_NIC="wg0.sing-box"

if [ $(sudo wg show | wc -l) -eq 0 ]; then
    echo "$(date): ${SERVER_WG_NIC} is down, being up..." | sudo tee -a /var/log/wg-quick-cron.log
    sudo wg-quick up ${SERVER_WG_NIC}
fi
EOF

    chmod +x /usr/local/bin/wg-quick-cron.sh >/dev/null 2>&1

    echo "NOTICE:"
    echo "  - Add a new cron schedule?"
    echo ""
    echo '      (crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/wg-quick-cron.sh") | crontab -'
    echo ""
    echo "  - Edit it again?"
    echo ""
    echo "      crontab -e"
    echo ""
    exit 0
}

function sing_box_run_cron() {
    cat >/usr/local/bin/sing-box-run-cron.sh <<'EOF'
#!/bin/bash

if [ $(ps aux | grep "sing-box run -c /etc/sing-box/" | wc -l) -eq 1 ]; then
    echo "$(date): sing-box is closed, reopening..." | sudo tee -a /var/log/sing-box-run-cron.log
    sudo sing-box run -c /etc/sing-box/config.json5
fi
EOF

    chmod +x /usr/local/bin/sing-box-run-cron.sh >/dev/null 2>&1

    echo "NOTICE:"
    echo "  - Add a new cron schedule?"
    echo ""
    echo '      (crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/sing-box-run-cron.sh") | crontab -'
    echo ""
    echo "  - Edit it again?"
    echo ""
    echo "      crontab -e"
    echo ""
    exit 0
}

function help() {
    cat <<EOF
USAGE
    bash sing-box.sh [OPTION]

OPTION
    -h, --help                Show help manual
    -i, --install             Install sing-box@v1.13.0-stable[server] or sing-box@v1.12.22-stable[client]
    -gw, --generate-wireguard Generate 3[/2] files: "wg0.sing-box.conf" and "config[.ipv4].json5"
    -gt, --generate-tailscale Generate 2[/1] file[s]: "config[.ipv4].json5"
    -r, --remove              Uninstall sing-box and remove all configuration files
    -aw, --add-wireguard      Add a "wg-quick up wg0.sing-box" cron schedule
    -at, --add-tailscale      Add a "sing-box run -c /etc/sing-box/config.json5" cron schedule
EOF
    exit 0
}

function main() {
    distribution
    root

    if [ "$#" -eq 0 ]; then
        help
    fi

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)
                help
                ;;
            -i|--install)
                install
                ;;
            -gw|--generate-wireguard)
                generate_wireguard
                ;;
            -gt|--generate-tailscale)
                generate_tailscale
                ;;
            -r|--remove)
                remove
                ;;
            -aw|--add-wireguard)
                wg_quick_cron
                ;;
            -at|--add-tailscale)
                sing_box_run_cron
                ;;
            *)
                echo "ERROR: Invalid option \"$1\"!"
                exit 1
                ;;
        esac
        shift
    done
}

main "$@"
