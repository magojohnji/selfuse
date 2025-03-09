# nginx-http3-boringssl

This repository contains the build configuration for compiling NGINX with BoringSSL support and enabling HTTP/3 (QUIC) functionality.

## Modules

- ngx_brotli
- http_v2_module
- http_v3_module
- http_ssl_module
- http_gunzip_module
- http_sub_module
- http_addition_module
- http_realip_module
- http_mp4_module

## Install

Run the installation script:

```sh
sudo ./install.sh install
```

After installation, start the NGINX service:

```sh
sudo systemctl start nginx
```

The configuration file is located at `/usr/local/nginx/conf/nginx.conf`, and you can modify it as needed.

## Warning

All builds are performed through an automated process and follow the latest BoringSSL sources and the latest NGINX mainline version. This repository itself does not check for defects or vulnerabilities in the built NGINX, nor does it provide any guarantees. If you intend to use it in a production environment, please evaluate it yourself.
