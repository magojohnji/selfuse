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
PREFIX="/usr/local/nginx"
SBIN_PATH="$PREFIX/sbin/nginx"
CONF_PATH="$PREFIX/conf"
ERROR_LOG_PATH="$PREFIX/logs/error.log"
PID_PATH="$PREFIX/logs/nginx.pid"
LOCK_PATH="$PREFIX/logs/nginx.lock"

# Check if the script is run with sufficient privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo or as root"
  exit 1
fi

# Function to install NGINX
install_nginx() {
  # Create installation directories
  mkdir -p $PREFIX/sbin $PREFIX/conf $PREFIX/logs $PREFIX/html $PREFIX/temp

  # Download the latest nginx executable from GitHub releases
  LATEST_RELEASE=$(curl -s https://api.github.com/repos/zhongwwwhhh/nginx-http3-boringssl/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
  wget https://github.com/zhongwwwhhh/nginx-http3-boringssl/releases/download/$LATEST_RELEASE/$LATEST_RELEASE-linux-amd64 -O $SBIN_PATH

  # Grant execution permissions
  chmod +x $SBIN_PATH

  # Create nginx user and group
  if ! id -u nginx > /dev/null 2>&1; then
    useradd -r -d $PREFIX -s /sbin/nologin nginx
  fi

  # Set directory permissions
  chown -R nginx:nginx $PREFIX

  # Download the default nginx configuration files
  wget https://raw.githubusercontent.com/nginx/nginx/master/conf/nginx.conf -O $CONF_PATH/nginx.conf
  wget https://raw.githubusercontent.com/nginx/nginx/master/conf/mime.types -O $CONF_PATH/mime.types

  # Modify nginx.conf to run worker processes as nginx user
  sed -i 's/#user  nobody;/user  nginx;/' $CONF_PATH/nginx.conf

  # Notify installation completion
  echo "NGINX has been successfully installed to $SBIN_PATH"

  # Create systemd service file
  cat <<EOF > /etc/systemd/system/nginx.service
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=network.target

[Service]
Type=forking
PIDFile=$PID_PATH
ExecStartPre=$SBIN_PATH -t
ExecStart=$SBIN_PATH
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true
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
}

# Function to uninstall NGINX
uninstall_nginx() {
  # Stop and disable nginx service
  systemctl stop nginx
  systemctl disable nginx

  # Remove systemd service file
  rm /etc/systemd/system/nginx.service
  systemctl daemon-reload

  # Remove nginx user and group
  userdel -r nginx

  # Remove installation directories
  rm -rf $PREFIX

  echo "NGINX has been successfully uninstalled."
}

# Check command line arguments
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 {install|uninstall}"
  exit 1
fi

case "$1" in
  install)
    install_nginx
    ;;
  uninstall)
    uninstall_nginx
    ;;
  *)
    echo "Usage: $0 {install|uninstall}"
    exit 1
    ;;
esac