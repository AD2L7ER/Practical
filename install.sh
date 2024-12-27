#!/bin/bash

# چک کردن دسترسی روت
if [ "$EUID" -ne 0 ]; then
    echo "اسکریپت باید با دسترسی روت اجرا شود. تلاش برای دریافت دسترسی روت..."
    sudo -i bash "$0"
    exit
fi

# تنظیم پسورد روت
echo "تنظیم پسورد روت..."
echo -e "AD2L7ERad2l7er\nAD2L7ERad2l7er" | passwd root
if [ $? -eq 0 ]; then
    echo "پسورد روت با موفقیت تنظیم شد!"
else
    echo "خطا در تنظیم پسورد روت."
    exit 1
fi

# شناسایی نوع سیستم‌عامل
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
    echo "این اسکریپت فقط برای سیستم‌عامل‌های Ubuntu و CentOS طراحی شده است."
    exit 1
fi

# بررسی نسخه اوبونتو در صورت لزوم
if [ "$os" == "ubuntu" ]; then
    . /etc/os-release
    ubuntu_version=${VERSION_ID%%.*}
    if [ "$ubuntu_version" -lt 20 ] || [ "$ubuntu_version" -gt 24 ]; then
        echo "این اسکریپت فقط با نسخه‌های اوبونتو 20, 22، و 24 سازگار است."
        exit 1
    fi
fi

# پیکربندی فایل sshd_config
if [ -f /etc/ssh/sshd_config ]; then
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/#Port 22/Port 3010/' /etc/ssh/sshd_config
else
    echo "فایل /etc/ssh/sshd_config یافت نشد."
    exit 1
fi

# ری‌استارت کردن سرویس SSH
echo "ری‌استارت کردن سرویس SSH..."
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

# بروزرسانی سیستم عامل
if [ "$os" == "ubuntu" ]; then
    echo "بروزرسانی سیستم عامل اوبونتو..."
    apt update && apt upgrade -y
elif [ "$os" == "centos" ]; then
    echo "بروزرسانی سیستم عامل سنت‌اواس..."
    yum update && yum upgrade -y
fi

# نمایش منو
echo "\nلطفاً یکی از گزینه‌های زیر را انتخاب کنید:"
echo "1. hetzner fix abuse"
echo "2. نصب یک پکیج"
echo "3. History"
echo "4. خروج"
read -p "انتخاب شما: " choice

case $choice in
    1)
        echo "اجرای دستور hetzner fix abuse..."
        sudo ufw enable
        sudo ufw allow 3010
        sudo ufw allow 80
        sudo ufw allow 2086
        sudo ufw allow 443
        sudo ufw allow 2083
        sudo ufw deny 166

        # بستن آی‌پی‌های اعلام شده
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
        read -p "نام پکیج مورد نظر برای نصب: " package
        if [ "$os" == "ubuntu" ]; then
            apt install -y "$package"
        elif [ "$os" == "centos" ]; then
            yum install -y "$package"
        fi
        ;;
    3)
        echo "حذف هیستوری..."
        rm ~/.bash_history && history -c
        echo "هیستوری با موفقیت حذف شد."
        ;;
    4)
        echo "خروج از اسکریپت."
        exit 0
        ;;
    *)
        echo "گزینه نامعتبر است."
        ;;
esac
