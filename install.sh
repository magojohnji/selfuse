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
LOG_PATH="$PREFIX/logs"
ERROR_LOG_PATH="$LOG_PATH/error.log"
ACCESS_LOG_PATH="$LOG_PATH/access.log"
PID_PATH="$LOG_PATH/nginx.pid"
LOCK_PATH="$LOG_PATH/nginx.lock"

# Check if the script is run with sufficient privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo or as root"
  exit 1
fi

# Function to install NGINX
install_nginx() {
  # Create installation directories
  mkdir -p $PREFIX/sbin $PREFIX/conf $PREFIX/logs $PREFIX/html $PREFIX/temp $PREFIX/conf/sites-enabled $PREFIX/conf/sites-available $PREFIX/conf/conf.d

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
  chown -R nginx:nginx $PREFIX/conf/sites-enabled $PREFIX/conf/sites-available $PREFIX/conf/conf.d

  # Download the default nginx configuration files
  wget https://raw.githubusercontent.com/zhongwwwhhh/nginx-http3-boringssl/master/conf/nginx.conf -O $CONF_PATH/nginx.conf
  wget https://raw.githubusercontent.com/nginx/nginx/master/conf/mime.types -O $CONF_PATH/mime.types

  # Create a symbolic link for nginx
  ln -s $SBIN_PATH /usr/local/bin/nginx

  # Notify installation completion
  echo "NGINX has been successfully installed to $SBIN_PATH"
  echo "Please run 'source /etc/profile' to update your environment variables."

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

  # Remove installation directories
  rm -rf $PREFIX || echo "Failed to remove installation directories. They may not exist."

  # Remove symbolic link for nginx
  rm /usr/local/bin/nginx || echo "Failed to remove symbolic link for nginx. It may not exist."

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