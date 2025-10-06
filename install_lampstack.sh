#!/bin/bash
# =========================================================
# ⚙️  Auto Installer LAMP Stack (Apache2 + PHP-FPM + MariaDB)
# 🧠  Full Tuning + Interaktif
# 👨‍🏫  by Abdur Rozak - SMKS YASMIDA Ambarawa
# 🌐  GitHub: https://github.com/abdurrozakskom
# License: MIT
# =========================================================
# YouTube  : https://www.youtube.com/@AbdurRozakSKom
# Instagram: https://instagram.com/abdurrozak.skom
# Facebook : https://facebook.com/abdurrozak.skom
# TikTok   : https://tiktok.com/abdurrozak.skom
# Threads  : https://threads.com/@abdurrozak.skom
# Lynk.id  : https://lynk.id/abdurrozak.skom
# Donasi:
# • Saweria  : https://saweria.co/abdurrozakskom
# • Trakteer : https://trakteer.id/abdurrozakskom/gift
# • Paypal   : https://paypal.me/abdurrozakskom
# =========================================================


# 🎨 Warna
GREEN="\e[32m"; CYAN="\e[36m"; RED="\e[31m"; YELLOW="\e[33m"; RESET="\e[0m"

line() { printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '='; }

# =========================================================
# 🧩 Bagian Interaktif
# =========================================================
clear
line
echo -e "${CYAN}🔧 [1/9] Konfigurasi Awal - Input Interaktif${RESET}"
line

SERVER_IP=$(hostname -I | awk '{print $1}')
echo -e "🌍 Deteksi Otomatis IP Server: ${YELLOW}$SERVER_IP${RESET}"

read -p "Masukkan Server Name / Domain (contoh: smkyasmida.sch.id): " SERVER_NAME
read -p "Masukkan Nama Database: " DB_NAME
read -p "Masukkan User Database: " DB_USER
read -sp "Masukkan Password Database: " DB_PASS
echo ""
line

# =========================================================
# 🌐 Cek Koneksi Internet
# =========================================================
echo -e "${CYAN}🌐 [2/9] Mengecek koneksi internet...${RESET}"
if ! ping -c 1 google.com &> /dev/null; then
  echo -e "${RED}❌ Tidak ada koneksi internet.${RESET}"; exit 1
else
  echo -e "${GREEN}✅ Internet OK.${RESET}"
fi

# =========================================================
# 🔄 Update Sistem
# =========================================================
line
echo -e "${CYAN}🔄 [3/9] Update Sistem...${RESET}"
apt update -y

# =========================================================
# ⚙️ Apache2 Install + Tuning
# =========================================================
line
echo -e "${CYAN}⚙️ [4/9] Instalasi & Tuning Apache2...${RESET}"
apt install apache2 -y
systemctl enable apache2
systemctl start apache2

a2enmod rewrite headers expires deflate ssl
a2dissite 000-default.conf
systemctl reload apache2

# Tambahkan konfigurasi tuning Apache
cat <<EOF > /etc/apache2/conf-available/performance-tuning.conf
# Apache Performance Tuning
HostnameLookups Off
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 3

<IfModule mpm_event_module>
    StartServers 2
    MinSpareThreads 25
    MaxSpareThreads 75
    ThreadsPerChild 25
    MaxRequestWorkers 150
    MaxConnectionsPerChild 1000
</IfModule>

ServerTokens Prod
ServerSignature Off

<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript
</IfModule>

<IfModule mod_expires.c>
  ExpiresActive On
  ExpiresByType image/jpg "access plus 1 month"
  ExpiresByType image/jpeg "access plus 1 month"
  ExpiresByType image/gif "access plus 1 month"
  ExpiresByType image/png "access plus 1 month"
  ExpiresByType text/css "access plus 1 week"
  ExpiresByType application/javascript "access plus 1 week"
  ExpiresByType text/html "access plus 600 seconds"
</IfModule>
EOF
a2enconf performance-tuning
systemctl reload apache2

# =========================================================
# 🧩 PHP-FPM Install + Tuning
# =========================================================
line
echo -e "${CYAN}🐘 [5/9] Instalasi PHP + PHP-FPM + Ekstensi Umum...${RESET}"
apt install php php-fpm php-mysql php-cli php-curl php-gd php-zip php-mbstring php-xml php-bcmath -y
systemctl enable php*-fpm
systemctl start php*-fpm

PHP_INI=$(php -r "echo php_ini_loaded_file();")
if [ -f "$PHP_INI" ]; then
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' $PHP_INI
    sed -i 's/^post_max_size = .*/post_max_size = 128M/' $PHP_INI
    sed -i 's/^memory_limit = .*/memory_limit = 256M/' $PHP_INI
    sed -i 's/^max_execution_time = .*/max_execution_time = 300/' $PHP_INI
    sed -i 's/^;date.timezone =.*/date.timezone = Asia\\/Jakarta/' $PHP_INI
fi

PHP_FPM_CONF=$(find /etc/php -name "www.conf" | head -n 1)
sed -i 's/^pm = .*/pm = dynamic/' $PHP_FPM_CONF
sed -i 's/^pm.max_children = .*/pm.max_children = 20/' $PHP_FPM_CONF
sed -i 's/^pm.start_servers = .*/pm.start_servers = 4/' $PHP_FPM_CONF
sed -i 's/^pm.min_spare_servers = .*/pm.min_spare_servers = 2/' $PHP_FPM_CONF
sed -i 's/^pm.max_spare_servers = .*/pm.max_spare_servers = 6/' $PHP_FPM_CONF

systemctl restart php*-fpm

# Integrasi Apache + PHP-FPM
a2enconf php*-fpm
systemctl reload apache2

# =========================================================
# 🗄️ MariaDB Install + Tuning
# =========================================================
line
echo -e "${CYAN}🗄️ [6/9] Instalasi & Tuning MariaDB...${RESET}"
apt install mariadb-server mariadb-client -y
systemctl enable mariadb
systemctl start mariadb

# Buat database otomatis
mysql -e "CREATE DATABASE ${DB_NAME};"
mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Tuning MariaDB (InnoDB)
cat <<EOF > /etc/mysql/mariadb.conf.d/99-performance.cnf
[mysqld]
innodb_buffer_pool_size = 512M
innodb_log_file_size = 128M
innodb_flush_log_at_trx_commit = 2
query_cache_size = 64M
max_connections = 200
thread_cache_size = 50
table_open_cache = 2048
EOF

systemctl restart mariadb

# =========================================================
# 🌐 Konfigurasi VirtualHost dengan PHP-FPM
# =========================================================
line
echo -e "${CYAN}🐘 [7/9] Konfigurasi VirtualHost dengan PHP-FPM...${RESET}"
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
PHP_FPM_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"

cat <<EOF > /etc/apache2/sites-available/$SERVER_NAME.conf
<VirtualHost *:80>
    ServerAdmin webmaster@$SERVER_NAME
    ServerName $SERVER_NAME
    ServerAlias www.$SERVER_NAME
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Integrasi PHP-FPM
    <FilesMatch \.php$>
        SetHandler "proxy:unix:${PHP_FPM_SOCK}|fcgi://localhost/"
    </FilesMatch>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined

    # Security & Performance
    ServerSignature Off
    ServerTokens Prod
</VirtualHost>
EOF

a2ensite $SERVER_NAME.conf
a2dissite 000-default.conf
a2enmod proxy_fcgi setenvif rewrite headers expires deflate ssl
systemctl reload apache2

# =========================================================
# 🔥 Firewall
# =========================================================
if command -v ufw >/dev/null 2>&1; then
  line
  echo -e "${CYAN}🔥 [8/9] Mengatur Firewall...${RESET}"
  ufw allow 'Apache Full'
  ufw allow 3306/tcp
fi

# =========================================================
# ✅ Verifikasi Layanan
# =========================================================
line
echo -e "${CYAN}🔍 [9/9] Mengecek status layanan...${RESET}"
for svc in apache2 mariadb php*-fpm; do
  systemctl is-active --quiet $svc && echo -e "${GREEN}✅ $svc OK${RESET}" || echo -e "${RED}❌ $svc Gagal${RESET}"
done

# =========================================================
# 🎉 Selesai
# =========================================================
line
echo -e "${GREEN}🎉 Instalasi LAMP Stack Selesai!${RESET}"
echo -e "🌍 Domain: ${CYAN}$SERVER_NAME${RESET}"
echo -e "🌐 IP Server: ${YELLOW}$SERVER_IP${RESET}"
echo -e "🗄️ Database: ${YELLOW}$DB_NAME${RESET}"
echo -e "👤 User DB: ${YELLOW}$DB_USER${RESET}"
echo -e "🔑 Password: ${YELLOW}$DB_PASS${RESET}"
echo -e "📁 Web Root: /var/www/html"
line
# ---- Credit Author ----
echo -e "${CYAN}📌 Credit Author:${RESET}"
echo -e "${YELLOW}Abdur Rozak, SMKS YASMIDA Ambarawa${RESET}"
echo -e "${YELLOW}GitHub : \e]8;;https://github.com/abdurrozakskom\ahttps://github.com/abdurrozakskom\e]8;;\a${RESET}"
echo -e "${YELLOW}YouTube: \e]8;;https://www.youtube.com/@AbdurRozakSKom\ahttps://www.youtube.com/@AbdurRozakSKom\e]8;;\a${RESET}"
echo ""
# ---- Donasi ----
echo -e "${CYAN}💖 Jika script ini bermanfaat, silakan donasi untuk mendukung pengembangan:${RESET}"
echo -e "${YELLOW}• Saweria  : \e]8;;https://saweria.co/abdurrozakskom\ahttps://saweria.co/abdurrozakskom\e]8;;\a${RESET}"
echo -e "${YELLOW}• Trakteer : \e]8;;https://trakteer.id/abdurrozakskom/gift\ahttps://trakteer.id/abdurrozakskom/gift\e]8;;\a${RESET}"
echo -e "${YELLOW}• Paypal   : \e]8;;https://paypal.me/abdurrozakskom\ahttps://paypal.me/abdurrozakskom\e]8;;\a${RESET}"
echo ""
# ---- Sosial Media ----
echo -e "${CYAN}🌐 Ikuti sosial media resmi untuk update & info:${RESET}"
echo -e "${YELLOW}• GitHub    : \e]8;;https://github.com/abdurrozakskom\ahttps://github.com/abdurrozakskom\e]8;;\a${RESET}"
echo -e "${YELLOW}• Lynk.id   : \e]8;;https://lynk.id/abdurrozak.skom\ahttps://lynk.id/abdurrozak.skom\e]8;;\a${RESET}"
echo -e "${YELLOW}• Instagram : \e]8;;https://instagram.com/abdurrozak.skom\ahttps://instagram.com/abdurrozak.skom\e]8;;\a${RESET}"
echo -e "${YELLOW}• Facebook  : \e]8;;https://facebook.com/abdurrozak.skom\ahttps://facebook.com/abdurrozak.skom\e]8;;\a${RESET}"
echo -e "${YELLOW}• TikTok    : \e]8;;https://tiktok.com/abdurrozak.skom\ahttps://tiktok.com/abdurrozak.skom\e]8;;\a${RESET}"
echo -e "${YELLOW}• Threads   : \e]8;;https://threads.com/@abdurrozak.skom\ahttps://threads.com/@abdurrozak.skom\e]8;;\a${RESET}"
echo -e "${YELLOW}• YouTube   : \e]8;;https://www.youtube.com/@AbdurRozakSKom\ahttps://www.youtube.com/@AbdurRozakSKom\e]8;;\a${RESET}"
line