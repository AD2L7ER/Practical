#!/bin/bash

#############################
#        FUNCTIONS         #
#############################

# Check for root access
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root. Please run the script again with 'sudo'."
        exit 1
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
        echo -e "\e[1;32mRoot password set successfully!\e[0m"
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
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Configure sshd_config
configure_ssh() {
    if [ ! -f /etc/ssh/sshd_config ]; then
        echo "File /etc/ssh/sshd_config not found. Please ensure SSH is installed."
        exit 1
    fi

    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak  # Backup the sshd_config
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/#Port 22/Port 3010/' /etc/ssh/sshd_config
}

# Restart SSH service
restart_ssh_service() {
    echo "Restarting SSH service..."
    if [ "$os" == "ubuntu" ]; then
        if command -v systemctl &> /dev/null; then
            systemctl restart ssh || { echo "Failed to restart SSH"; exit 1; }
        else
            service ssh restart || { echo "Failed to restart SSH"; exit 1; }
        fi
    elif [ "$os" == "centos" ]; then
        if command -v systemctl &> /dev/null; then
            systemctl restart sshd || { echo "Failed to restart SSH"; exit 1; }
        else
            service sshd restart || { echo "Failed to restart SSH"; exit 1; }
        fi
    else
        echo "Unsupported OS for SSH service restart"
        exit 1
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
    echo -e "
You have selected Hetzner Fix Abuse. Please confirm your choice:"
    echo -e "1. Proceed with Hetzner Fix Abuse actions"
    echo -e "2. Return to Main Menu"
    read -p "Your choice: " abuse_choice

    case $abuse_choice in
        1)
            echo -e "$(tput setaf 2)$(tput bold)Executing hetzner fix abuse...$(tput sgr0)"
            
            # Check if ufw is installed
            if ! command -v ufw &>/dev/null; then
                echo "ufw is not installed. Installing ufw..."
                if [ "$os" == "ubuntu" ]; then
                    apt-get install -y ufw
                elif [ "$os" == "centos" ]; then
                    yum install -y ufw
                else
                    echo "Unknown OS. Please install ufw manually or remove ufw usage."
                    return
                fi
            fi

            if ! sudo ufw status | grep -q 'Status: active'; then
                echo "Activating UFW..."
                sudo ufw --force enable > /dev/null 2>&1
            else
                echo "UFW is already active. Skipping activation."
            fi

            # Make sure port 3010 is open for SSH
            sudo ufw allow 3010 comment 'Ensure SSH connectivity'
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
                "103.58.50.1/24" "25.0.0.0/19" "103.29.38.0/24" "103.49.99.0/24"
            do
                sudo ufw deny out from any to "$ip"
            done

            echo -e "$(tput setaf 2)$(tput bold)Firewall rules applied successfully.$(tput sgr0)"
            ;;
        2)
            # Just return here; main_menu will be called from the case block in main_menu()
            return
            ;;
        *)
            echo -e "[1;31mInvalid choice. Returning to main menu.[0m"
            return
            ;;
    esac
}

# Clear bash history with user confirmation
clear_history() {
    echo -e "\033[1;32mWhat would you like to do?\033[0m"
    echo -e "1. Continue (Clear history)"
    echo -e "2. Return to Main Menu"
    read -p "Your choice: " history_choice

    case $history_choice in
        1)
            echo -e "$(tput setaf 1)$(tput bold)Clearing bash history...\033[0m"
            if [ -f ~/.bash_history ]; then
                rm ~/.bash_history && history -c
                echo -e "$(tput setaf 2)$(tput bold)History cleared successfully.\033[0m"
            else
                echo -e "$(tput setaf 3)No bash history file found. Skipping.\033[0m"
            fi
            ;;
        2)
            return
            ;;
        *)
            echo -e "\033[1;31mInvalid choice. Returning to the main menu.\033[0m"
            return
            ;;
    esac
}

# Install x-ui with continue/return option
install_x_ui() {
    echo -e "\033[1;32mYou have selected x-ui Installation. What do you want to do?\033[0m"
    echo -e "1. Continue (Install x-ui)"
    echo -e "2. Return to Main Menu"
    read -p "Your choice: " choice

    case $choice in
        1)
            echo -e "\033[1;32mInstalling x-ui...\033[0m"
            bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
            echo "Installation complete!"
            ;;
        2)
            return
            ;;
        *)
            echo -e "\033[1;31mInvalid choice. Returning to the main menu.\033[0m"
            return
            ;;
    esac
}

# Perform Speedtest
do_speedtest() {
    echo -e "\nPlease select a Speedtest option:"
    echo -e "1. Global\033[1;34m (Run global benchmark)\033[0m"
    echo -e "2. Iran\033[1;34m (Run Iran-specific benchmark)\033[0m"
    echo -e "3. Return to Main Menu\033[1;34m (Go back to the main menu)\033[0m"
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
        3)
            return
            ;;
        *)
            echo -e "\033[1;31mInvalid choice. Returning to main menu.\033[0m"
            return
            ;;
    esac
}

# Configure 6to4 tunneling
configure_6to4_tunneling() {
    echo -e "\nPlease select a tunneling configuration option:"
    echo -e "1. Configure for Iran Server\033[1;34m (Setup tunneling for Iran)\033[0m"
    echo -e "2. Configure for Foreign Server\033[1;34m (Setup tunneling for outside servers)\033[0m"
    echo -e "3. Return to Main Menu\033[1;34m (Go back to the main menu)\033[0m"
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
        3)
            return
            ;;
        *)
            echo -e "\033[1;31mInvalid choice. Returning to main menu.\033[0m"
            return
            ;;
    esac
}

# Install Gost tunnels
install_gost_tunnels() {
    echo -e "\033[1;32mInstalling Gost tunnels...\033[0m"
    bash <(curl -Ls https://raw.githubusercontent.com/masoudgb/Gost-ip6/main/install.sh)
    echo -e "\033[1;32mGost tunnels installation completed.\033[0m"
}


nanem_server() {
    while true; do
        clear
        echo -e "
+----------------------------------------------------+
▒              Nanem Server Configuration             ▒
▒----------------------------------------------------▒
▒ 1. Google DNS                                       ▒
▒ 2. Cloudflare DNS                                   ▒
▒ 3. OpenDNS                                          ▒
▒ 4. Quad9 DNS                                        ▒
▒ 5. 403 DNS                                          ▒
▒ 6. Electrotm DNS                                    ▒
▒ 7. Begzar DNS                                       ▒
▒ 8. Shecan DNS                                       ▒
▒ 0. Return to Main Menu                              ▒
+----------------------------------------------------+
"
        read -p "Your choice: " nanem_choice

        case $nanem_choice in
            1) 
                echo "Setting DNS to Google..."
                set_dns "8.8.8.8" "8.8.4.4" "2001:4860:4860::8888" "2001:4860:4860::8844"
                ;;
            2) 
                echo "Setting DNS to Cloudflare..."
                set_dns "1.1.1.1" "1.0.0.1" "2606:4700:4700::1111" "2606:4700:4700::1001"
                ;;
            3) 
                echo "Setting DNS to OpenDNS..."
                set_dns "208.67.222.222" "208.67.220.220" "2620:119:35::35" "2620:119:53::53"
                ;;
            4)
                echo "Setting DNS to Quad9..."
                set_dns "9.9.9.9" "149.112.112.112" "2620:fe::fe" "2620:fe::9"
                ;;
            5)
                echo "Setting DNS to 403 DNS..."
                set_dns "10.202.10.10" "10.202.10.11"
                ;;
            6)
                echo "Setting DNS to Electrotm DNS..."
                set_dns "78.157.42.100" "78.157.42.101"
                ;;
            7)
                echo "Setting DNS to Begzar DNS..."
                set_dns "185.51.200.2" "185.51.200.1"
                ;;
            8)
                echo "Setting DNS to Shecan DNS..."
                set_dns "178.22.122.100" "185.51.200.2"
                ;;
            0) 
                return
                ;;
            *) 
                echo "Invalid choice. Please try again."
                ;;
        esac
        echo -e "[1;32mDNS has been updated successfully![0m"
        read -p "Press Enter to return to the Nanem Server menu."
    done
}

set_dns() {
    local ipv4_primary=$1
    local ipv4_secondary=$2
    local ipv6_primary=$3
    local ipv6_secondary=$4

    # Backup existing resolv.conf
    cp /etc/resolv.conf /etc/resolv.conf.bak

    # Set the new DNS
    echo "nameserver $ipv4_primary" > /etc/resolv.conf
    echo "nameserver $ipv4_secondary" >> /etc/resolv.conf
    if [ -n "$ipv6_primary" ]; then
        echo "nameserver $ipv6_primary" >> /etc/resolv.conf
    fi
    if [ -n "$ipv6_secondary" ]; then
        echo "nameserver $ipv6_secondary" >> /etc/resolv.conf
    fi

    # Make the change permanent by updating systemd-resolved
    if [ -f /etc/systemd/resolved.conf ]; then
        sed -i "s/^#DNS=.*/DNS=$ipv4_primary $ipv4_secondary $ipv6_primary $ipv6_secondary/" /etc/systemd/resolved.conf
        sed -i "s/^#FallbackDNS=.*/FallbackDNS=/" /etc/systemd/resolved.conf
        systemctl restart systemd-resolved
    fi
}

#############################
#        MAIN MENU         #
#############################
main_menu() {
    clear  # Clear the screen before displaying the menu
    echo -e "
╔═══════════════════════════════════════════════╗
║                   Main Menu                   ║
╠═══════════════════════════════════════════════╣
║ 1. $(tput setaf 2)Hetzner Fix Abuse$(tput sgr0)                     ║
║ 2. $(tput setaf 3)History$(tput sgr0)                              ║
║ 3. $(tput setaf 4)x-ui Install$(tput sgr0)                         ║
║ 4. $(tput setaf 5)Speedtest$(tput sgr0)                            ║
║ 5. $(tput setaf 6)6to4 IPv6 Tunneling$(tput sgr0)                  ║
║ 6. $(tput setaf 1)Gost Tunnels$(tput sgr0)                         ║
║ 7. Nanem Server                                     ║
║ 0. $(tput setaf 7)Exit$(tput sgr0)                                 ║
╚═══════════════════════════════════════════════╝"
    read -p "Your choice: " main_choice

    case $main_choice in
        1) fix_abuse ; main_menu ;;
        2) clear_history ; main_menu ;;
        3) install_x_ui ; main_menu ;;
        4) do_speedtest ; main_menu ;;
        5) configure_6to4_tunneling ; main_menu ;;
        6) install_gost_tunnels ; main_menu ;;
            7) nanem_server ; main_menu ;;
0)
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
