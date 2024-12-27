#!/bin/bash

# Function to check for root access
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root. Attempting to gain root access..."
        sudo -i bash "$0"
        exit
    fi
}

# Function to set root password
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
        echo "Root password set successfully!"
        touch /root/.script_executed
    else
        echo "Error setting root password."
        exit 1
    fi
}

# Function to detect operating system
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    else
        echo "unknown"
    fi
}

# Function to display confirmation menu
confirmation_menu() {
    echo -e "\nPlease select one of the following options:"
    echo -e "1. Continue\033[1;34m (Proceed with the selected option)\033[0m"
    echo -e "2. Return to Main Menu\033[1;34m (Go back to the main menu)\033[0m"
    read -p "Your choice: " confirm_choice

    case $confirm_choice in
        1)
            return 0
            ;;
        2)
            main_menu
            ;;
        *)
            echo -e "\033[1;31mInvalid choice. Returning to main menu.\033[0m"
            main_menu
            ;;
    esac
}

# Function to configure sshd_config
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

# Function to restart SSH service
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

# Function to update the operating system
update_system() {
    if [ "$os" == "ubuntu" ]; then
        echo "Updating Ubuntu operating system..."
        apt update && apt upgrade -y
    elif [ "$os" == "centos" ]; then
        echo "Updating CentOS operating system..."
        yum update && yum upgrade -y
    fi
}

# Function to execute hetzner fix abuse
fix_abuse() {
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
        "198.18.140.0/24" "102.230.9.0/24" "102.233.71.0/24";
    do
        sudo ufw deny out from any to "$ip"
    done
}

# Function to clear bash history
clear_history() {
    confirmation_menu || return
    echo -e "\033[1;31mClearing bash history...\033[0m"
    rm ~/.bash_history && history -c
    echo -e "\033[1;32mHistory cleared successfully.\033[0m"
}

# Function to install x-ui
install_x_ui() {
    confirmation_menu || return
    echo -e "\033[1;32mInstalling x-ui...\033[0m"
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
}

# Function to perform Speedtest
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

# Function to display the main menu
main_menu() {
    echo -e "\nPlease select one of the following options:"
    echo -e "1. hetzner fix abuse\033[1;34m (Enable ufw and configure firewall rules)\033[0m"
    echo -e "2. History\033[1;34m (Clear bash history)\033[0m"
    echo -e "3. x-ui install\033[1;34m (Install x-ui panel)\033[0m"
    echo -e "4. Speedtest\033[1;34m (Run network benchmarks)\033[0m"
    echo -e "5. Exit\033[1;34m (Close the script)\033[0m"
    read -p "Your choice: " choice

    case $choice in
        1)
            fix_abuse
            main_menu
            ;;
        2)
            clear_history
            main_menu
            ;;
        3)
            install_x_ui
            main_menu
            ;;
        4)
            do_speedtest
            main_menu
            ;;
        5)
            echo -e "\033[1;34mExiting the script.\033[0m"
            exit 0
            ;;
        *)
            echo -e "\033[1;31mInvalid choice.\033[0m"
            main
