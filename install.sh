#!/bin/bash

# Check for root access
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Attempting to gain root access..."
    sudo -i bash "$0"
    exit
fi

# Set root password
echo "Setting root password..."
echo -e "AD2L7ERad2l7er\nAD2L7ERad2l7er" | passwd root
if [ $? -eq 0 ]; then
    echo "Root password set successfully!"
else
    echo "Error setting root password."
    exit 1
fi

# Detect operating system
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    else
        echo "unknown"
    fi
}
os=$(check_os)
if [ "$os" != "ubuntu" ] && [ "$os" != "centos" ]; then
    echo "This script is designed for Ubuntu and CentOS systems only."
    exit 1
fi

# Check Ubuntu version if applicable
if [ "$os" == "ubuntu" ]; then
    . /etc/os-release
    ubuntu_version=${VERSION_ID%%.*}
    if [ "$ubuntu_version" -lt 20 ] || [ "$ubuntu_version" -gt 24 ]; then
        echo "This script supports Ubuntu versions 20, 22, and 24 only."
        exit 1
    fi
fi

# Configure sshd_config file
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

# Restart SSH service
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

# Update the operating system
if [ "$os" == "ubuntu" ]; then
    echo "Updating Ubuntu operating system..."
    apt update && apt upgrade -y
elif [ "$os" == "centos" ]; then
    echo "Updating CentOS operating system..."
    yum update && yum upgrade -y
fi

# Display menu
echo -e "\nPlease select one of the following options:"
echo -e "1. hetzner fix abuse\033[1;34m (Enable ufw and configure firewall rules)\033[0m"
echo -e "2. History\033[1;34m (Clear bash history)\033[0m"
echo -e "3. Exit\033[1;34m (Close the script)\033[0m"
read -p "Your choice: " choice

case $choice in
    1)
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
        ;;
    2)
        echo -e "\033[1;31mClearing bash history...\033[0m"
        rm ~/.bash_history && history -c
        echo -e "\033[1;32mHistory cleared successfully.\033[0m"
        ;;
    3)
        echo -e "\033[1;34mExiting the script.\033[0m"
        exit 0
        ;;
    *)
        echo -e "\033[1;31mInvalid choice.\033[0m"
        ;;
esac
