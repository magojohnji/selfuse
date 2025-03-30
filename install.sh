#!/bin/bash

set -e

# Check if the system is supported (Debian-based only)
if ! grep -qEi "(debian|ubuntu)" /etc/*release; then
  echo "This script is only supported on Debian-based systems."
  exit 1
fi

# Check if curl and wget are installed
if ! command -v curl &> /dev/null || ! command -v wget &> /dev/null; then
  echo "curl and wget are required but not installed. Please install them and try again."
  exit 1
fi

# Check if systemctl is installed
if ! command -v systemctl &> /dev/null; then
  echo "systemctl is required but not installed. Please install it and try again."
  exit 1
fi

# Installation path
PREFIX="/usr/share/nginx"
SBIN_PATH="/usr/sbin/nginx"
CONF_PATH="/etc/nginx"
LOG_PATH="/var/log/nginx"
ERROR_LOG_PATH="$LOG_PATH/error.log"
ACCESS_LOG_PATH="$LOG_PATH/access.log"
PID_PATH="/run/nginx.pid"
LOCK_PATH="/var/lock/nginx.lock"
MODULES_PATH="/usr/lib/nginx/modules"
CLIENT_BODY_TEMP_PATH="/var/lib/nginx/body"
FASTCGI_TEMP_PATH="/var/lib/nginx/fastcgi"
PROXY_TEMP_PATH="/var/lib/nginx/proxy"
SCGI_TEMP_PATH="/var/lib/nginx/scgi"
UWSGI_TEMP_PATH="/var/lib/nginx/uwsgi"
CACHE_PATH="/var/cache/nginx"

# Check if the script is run with sufficient privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo or as root"
  exit 1
fi

# Function to install NGINX
install_nginx() {
  # Check if NGINX is already installed
  if command -v nginx &> /dev/null; then
    echo "NGINX is already installed. Please uninstall it first if you want to reinstall."
    exit 1
  fi

  # Confirm installation
  read -p "Are you sure you want to install NGINX? (y/N): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Installation cancelled."
    exit 0
  fi

  # Create installation directories
  mkdir -p $PREFIX $CONF_PATH $LOG_PATH $PREFIX/html $CONF_PATH/sites-enabled $CONF_PATH/sites-available $CONF_PATH/conf.d $MODULES_PATH $CLIENT_BODY_TEMP_PATH $FASTCGI_TEMP_PATH $PROXY_TEMP_PATH $SCGI_TEMP_PATH $UWSGI_TEMP_PATH $CACHE_PATH

  # Download the latest nginx executable from GitHub releases
  LATEST_RELEASE=$(curl -s https://api.github.com/repos/zhongwwwhhh/nginx-http3-boringssl/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
  wget https://github.com/zhongwwwhhh/nginx-http3-boringssl/releases/download/$LATEST_RELEASE/$LATEST_RELEASE-linux-amd64 -O $SBIN_PATH || { echo "Failed to download nginx executable"; exit 1; }

  # Grant execution permissions
  chmod +x $SBIN_PATH

  # Create nginx user and group
  if ! id -u nginx > /dev/null 2>&1; then
    useradd -r -d $PREFIX -s /sbin/nologin nginx
  fi

  # Set directory permissions
  chown -R nginx:nginx $PREFIX
  chown -R nginx:nginx $CONF_PATH/sites-enabled $CONF_PATH/sites-available $CONF_PATH/conf.d $MODULES_PATH $CLIENT_BODY_TEMP_PATH $FASTCGI_TEMP_PATH $PROXY_TEMP_PATH $SCGI_TEMP_PATH $UWSGI_TEMP_PATH $CACHE_PATH
  chmod 700 $CLIENT_BODY_TEMP_PATH $FASTCGI_TEMP_PATH $PROXY_TEMP_PATH $SCGI_TEMP_PATH $UWSGI_TEMP_PATH $CACHE_PATH

  # Download the default nginx configuration files
  wget https://raw.githubusercontent.com/zhongwwwhhh/nginx-http3-boringssl/master/conf/nginx.conf -O $CONF_PATH/nginx.conf || { echo "Failed to download nginx.conf"; exit 1; }
  wget https://raw.githubusercontent.com/nginx/nginx/master/conf/mime.types -O $CONF_PATH/mime.types || { echo "Failed to download mime.types"; exit 1; }

  # Notify installation completion
  echo "NGINX has been successfully installed to $SBIN_PATH"

  # Create systemd service file
  cat <<EOF > /etc/systemd/system/nginx.service
[Unit]
Description=A high performance web server and a reverse proxy server
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=$PID_PATH
ExecStartPre=$SBIN_PATH -t -q -g 'daemon on; master_process on;'
ExecStart=$SBIN_PATH -g 'daemon on; master_process on;'
ExecReload=$SBIN_PATH -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile $PID_PATH
TimeoutStopSec=5
KillMode=mixed
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

  # Reload systemd manager configuration
  systemctl daemon-reload

  # Enable and start nginx service
  systemctl enable nginx
  systemctl start nginx

  echo "NGINX service has been successfully created and started."

  # Create logrotate configuration for nginx
  cat <<EOF > /etc/logrotate.d/nginx
$ERROR_LOG_PATH $ACCESS_LOG_PATH {
    daily
    rotate 90
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        [ -f $PID_PATH ] && kill -USR1 \`cat $PID_PATH\`
    endscript
}
EOF
}

# Function to uninstall NGINX
uninstall_nginx() {
  # Confirm uninstallation
  read -p "Are you sure you want to uninstall NGINX? (y/N): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Uninstallation cancelled."
    exit 0
  fi

  # Stop and disable nginx service
  systemctl stop nginx || echo "Failed to stop nginx service. It may not be running."
  systemctl disable nginx || echo "Failed to disable nginx service. It may not be enabled."

  # Remove systemd service file
  rm /etc/systemd/system/nginx.service || echo "Failed to remove nginx service file. It may not exist."
  systemctl daemon-reload

  # Remove logrotate configuration for nginx
  rm /etc/logrotate.d/nginx || echo "Failed to remove logrotate configuration. It may not exist."

  # Remove nginx user and group
  userdel -r nginx || echo "Failed to remove nginx user and group. They may not exist."

  # Remove files
  rm -rf $PREFIX $SBIN_PATH $CONF_PATH $MODULES_PATH $CLIENT_BODY_TEMP_PATH $FASTCGI_TEMP_PATH $PROXY_TEMP_PATH $SCGI_TEMP_PATH $UWSGI_TEMP_PATH $CACHE_PATH || echo "Failed to remove files. They may not exist."

  echo "NGINX has been successfully uninstalled."
}

# Function to update NGINX
update_nginx() {
  # Check if NGINX is installed
  if ! command -v nginx &> /dev/null; then
    echo "NGINX is not installed. Please install it first before updating."
    exit 1
  fi

  # Confirm update
  read -p "Are you sure you want to update NGINX? (y/N): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Update cancelled."
    exit 0
  fi

  # Stop NGINX service
  systemctl stop nginx || { echo "Failed to stop NGINX service. Please check its status."; exit 1; }

  # Download the latest nginx executable from GitHub releases
  LATEST_RELEASE=$(curl -s https://api.github.com/repos/zhongwwwhhh/nginx-http3-boringssl/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
  wget https://github.com/zhongwwwhhh/nginx-http3-boringssl/releases/download/$LATEST_RELEASE/$LATEST_RELEASE-linux-amd64 -O $SBIN_PATH || { echo "Failed to download nginx executable"; exit 1; }

  # Grant execution permissions
  chmod +x $SBIN_PATH

  # Start NGINX service
  systemctl start nginx || { echo "Failed to start NGINX service. Please check its status."; exit 1; }

  echo "NGINX has been successfully updated to the latest version."
}

# Check command line arguments
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 {install|uninstall|update}"
  exit 1
fi

case "$1" in
  install)
    install_nginx
    ;;
  uninstall)
    uninstall_nginx
    ;;
  update)
    update_nginx
    ;;
  *)
    echo "Usage: $0 {install|uninstall|update}"
    exit 1
    ;;
esac