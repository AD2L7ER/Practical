#!/bin/bash

#############################
#        FUNCTIONS         #
#############################

# Check for root access
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root. Attempting to gain root access..."
        sudo -i bash "$0"
        exit
    fi
}

# Set root password
set_root_password() {
    if [ -f /root/.script_executed ]; then
        echo "Root password has already been set. Skipping this step."
        return
    fi

    echo "Please enter a new root password:"
    read -s root_password
    read -s -p "Confirm root password: " root_password_confirm

    if [ "$root_password" != "$root_password_confirm" ]; then
        echo -e "\nPasswords do not match. Please restart the script and try again."
        exit 1
    fi

    echo -e "$root_password\n$root_password" | passwd root
    if [ $? -eq 0 ]; then
        echo -e "\033[1;32mRoot password set successfully!\033[0m"
        touch /root/.script_executed
    else
        echo "Error setting root password."
        exit 1
    fi
}

# Detect operating system
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    else
        echo "unknown"
    fi
}

# Display confirmation menu
confirmation_menu() {
    echo -e "\nPlease select one of the following options:"
    echo -e "1. Continue\033[1;34m (Proceed with the selected option)\033[0m"
    echo -e "2. Return to Main Menu\033[1;34m (Go back to the main menu)\033[0m"
    read -p "Your choice: " confirm_choice

    case $confirm_choice in
        1) return 0 ;;
        2) main_menu ;;
        *)
            echo -e "\033[1;31mInvalid choice. Returning to main menu.\033[0m"
            main_menu
            ;;
    esac
}

# Configure sshd_config
configure_ssh() {
    if [ -f /etc/ssh/sshd_config ]; then
        sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
        sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        sed -i 's/#Port 22/Port 3010/' /etc/ssh/sshd_config
    else
        echo "File /etc/ssh/sshd_config not found."
        exit 1
    fi
}

# Restart SSH service
restart_ssh_service() {
    echo "Restarting SSH service..."
    if [ "$os" == "ubuntu" ]; then
        if command -v systemctl &> /dev/null; then
            systemctl restart ssh
        else
            service ssh restart
        fi
    elif [ "$os" == "centos" ]; then
        if command -v systemctl &> /dev/null; then
            systemctl restart sshd
        else
            service sshd restart
        fi
    fi
}

# Update the operating system
update_system() {
    if [ "$os" == "ubuntu" ]; then
        echo "Updating Ubuntu operating system..."
        apt update && apt upgrade -y
    elif [ "$os" == "centos" ]; then
        echo "Updating CentOS operating system..."
        yum update && yum upgrade -y
    fi
}

# Execute hetzner fix abuse
fix_abuse() {
    confirmation_menu || return
    echo -e "[1;32mExecuting hetzner fix abuse...[0m"
    echo "Activating UFW..."
    yes | sudo ufw enable
    confirmation_menu || return
    echo -e "\033[1;32mExecuting hetzner fix abuse...\033[0m"
    sudo ufw enable
    sudo ufw allow 3010
    sudo ufw allow 80
    sudo ufw allow 2086
    sudo ufw allow 443
    sudo ufw allow 2083
    sudo ufw deny 166

    # Block specified IP ranges
    for ip in \
        "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "100.64.0.0/10" "198.18.0.0/15" \
        "102.197.0.0/16" "102.0.0.0/8" "102.197.0.0/10" "169.254.0.0/16" "102.236.0.0/16" \
        "2.60.0.0/16" "5.1.41.0/12" "172.0.0.0/8" "192.0.0.0/8" "200.0.0.0/8" \
        "198.51.100.0/24" "203.0.113.0/24" "224.0.0.0/4" "240.0.0.0/4" "255.255.255.255/32" \
        "192.0.0.0/24" "192.0.2.0/24" "127.0.0.0/8" "127.0.53.53" "192.88.99.0/24" \
        "198.18.140.0/24" "102.230.9.0/24" "102.233.71.0/24" "185.235.86.0/24" "185.235.87.0/24" \
        "114.208.187.0/24" "216.218.185.0/24" "206.191.152.0/24" "45.14.174.0/24" "195.137.167.0/24" \
        "103.58.50.1/24" "25.0.0.0/19" "103.29.38.0/24" "103.49.99.0/24";
    do
        sudo ufw deny out from any to "$ip"
    done
}

# Clear bash history
clear_history() {
    confirmation_menu || return
    echo -e "\033[1;31mClearing bash history...\033[0m"
    rm ~/.bash_history && history -c
    echo -e "\033[1;32mHistory cleared successfully.\033[0m"
}

# Install x-ui
install_x_ui() {
    confirmation_menu || return
    echo -e "\033[1;32mInstalling x-ui...\033[0m"
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
}

# Perform Speedtest
do_speedtest() {
    confirmation_menu || return
    echo -e "\nPlease select a Speedtest option:"
    echo -e "1. Global\033[1;34m (Run global benchmark)\033[0m"
    echo -e "2. Iran\033[1;34m (Run Iran-specific benchmark)\033[0m"
    read -p "Your choice: " speedtest_choice

    case $speedtest_choice in
        1)
            echo -e "\033[1;32mRunning global benchmark...\033[0m"
            wget -qO- bench.sh | bash
            ;;
        2)
            echo -e "\033[1;32mRunning Iran-specific benchmark...\033[0m"
            wget -qO- network-speed.xyz | bash -s -- -r iran
            ;;
        *)
            echo -e "\033[1;31mInvalid choice for Speedtest. Returning to main menu.\033[0m"
            ;;
    esac
}

# Configure 6to4 tunneling
configure_6to4_tunneling() {
    confirmation_menu || return

    echo -e "\nPlease select a tunneling configuration option:"
    echo -e "1. Configure for Iran Server\033[1;34m (Setup tunneling for Iran)\033[0m"
    echo -e "2. Configure for Foreign Server\033[1;34m (Setup tunneling for outside servers)\033[0m"
    read -p "Your choice: " tunneling_choice

    case $tunneling_choice in
        1)
            echo -e "\033[1;32mConfiguring 6to4 tunneling for Iran server...\033[0m"
            read -p "Enter IPv4 address of Iran server: " ip_server_iran
            read -p "Enter IPv4 address of foreign server: " ip_server_foreign

            net_interface=$(ip route | grep default | awk '{print $5}')
            cat <<EOL > /etc/rc.local
#!/bin/bash
ip tunnel add 6to4tun_IR mode sit remote $ip_server_foreign local $ip_server_iran
ip -6 addr add 2001:470:1f10:e1f::1/64 dev 6to4tun_IR
ip link set 6to4tun_IR mtu 1480
ip link set 6to4tun_IR up
ip -6 tunnel add GRE6Tun_IR mode ip6gre remote 2001:470:1f10:e1f::2 local 2001:470:1f10:e1f::1
ip addr add 172.16.1.1/30 dev GRE6Tun_IR
ip link set GRE6Tun_IR mtu 1436
ip link set GRE6Tun_IR up
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -A POSTROUTING -o $net_interface -j MASQUERADE
iptables -A FORWARD -j ACCEPT
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
sysctl -p
service iptables save
service iptables restart
EOL

            chmod +x /etc/rc.local
            /etc/rc.local
            ;;
        2)
            echo -e "\033[1;32mConfiguring 6to4 tunneling for Foreign server...\033[0m"
            read -p "Enter IPv4 address of foreign server: " ip_server_foreign
            read -p "Enter IPv4 address of Iran server: " ip_server_iran

            net_interface=$(ip route | grep default | awk '{print $5}')
            cat <<EOL > /etc/rc.local
#!/bin/bash
ip tunnel add 6to4tun_KH mode sit remote $ip_server_iran local $ip_server_foreign
ip -6 addr add 2001:470:1f10:e1f::2/64 dev 6to4tun_KH
ip link set 6to4tun_KH mtu 1480
ip link set 6to4tun_KH up
ip -6 tunnel add GRE6Tun_KH mode ip6gre remote 2001:470:1f10:e1f::1 local 2001:470:1f10:e1f::2
ip addr add 172.16.1.2/30 dev GRE6Tun_KH
ip link set GRE6Tun_KH mtu 1436
ip link set GRE6Tun_KH up
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -A POSTROUTING -o $net_interface -j MASQUERADE
iptables -A FORWARD -j ACCEPT
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
sysctl -p
service iptables save
service iptables restart
EOL

            chmod +x /etc/rc.local
            /etc/rc.local
            ;;
        *)
            echo -e "\033[1;31mInvalid choice. Returning to main menu.\033[0m"
            ;;
    esac
}

# Install Gost tunnels
install_gost_tunnels() {
    confirmation_menu || return
    echo -e "\033[1;32mInstalling Gost tunnels...\033[0m"
    bash <(curl -Ls https://raw.githubusercontent.com/masoudgb/Gost-ip6/main/install.sh)
}

#############################
#        MAIN MENU         #
#############################
main_menu() {
    echo -e "\n================ Main Menu ================"
    echo -e "1. Hetzner Fix Abuse\033[1;34m (Enable ufw and configure firewall rules)\033[0m"
    echo -e "2. History\033[1;34m (Clear bash history)\033[0m"
    echo -e "3. x-ui Install\033[1;34m (Install x-ui panel)\033[0m"
    echo -e "4. Speedtest\033[1;34m (Run network benchmarks)\033[0m"
    echo -e "5. 6to4 IPv6 Tunneling\033[1;34m (Configure tunneling options)\033[0m"
    echo -e "6. Gost tunnels\033[1;34m (Install Gost Tunneling)\033[0m"
    echo -e "7. Exit\033[1;34m (Close the script)\033[0m"
    read -p "Your choice: " main_choice

    case $main_choice in
        1) fix_abuse ;;
        2) clear_history ;;
        3) install_x_ui ;;
        4) do_speedtest ;;
        5) configure_6to4_tunneling ;;
        6) install_gost_tunnels ;;
        7)
            echo -e "\033[1;32mExiting script. Goodbye!\033[0m"
            exit 0
            ;;
        *)
            echo -e "\033[1;31mInvalid choice. Please select a valid option.\033[0m"
            main_menu
            ;;
    esac
}

#############################
#       SCRIPT START       #
#############################
check_root
os=$(detect_os)
set_root_password
configure_ssh
restart_ssh_service
update_system
main_menu
