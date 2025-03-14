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
- http_auth_request_module
- http_dav_module
- http_flv_module
- http_gzip_static_module
- http_random_index_module
- http_secure_link_module
- http_slice_module

## Install

Run the installation script:

```sh
sudo ./install.sh install
```

After installation, start the NGINX service:

```sh
sudo systemctl start nginx
```

## Default Locations and User

```sh
--prefix=/usr/share/nginx 
--conf-path=/etc/nginx/nginx.conf 
--http-log-path=/var/log/nginx/access.log 
--error-log-path=/var/log/nginx/error.log 
--lock-path=/var/lock/nginx.lock 
--pid-path=/run/nginx.pid 
--modules-path=/usr/lib/nginx/modules 
--http-client-body-temp-path=/var/lib/nginx/body 
--http-fastcgi-temp-path=/var/lib/nginx/fastcgi 
--http-proxy-temp-path=/var/lib/nginx/proxy 
--http-scgi-temp-path=/var/lib/nginx/scgi 
--http-uwsgi-temp-path=/var/lib/nginx/uwsgi
```

## Encrypted Client Hello (ECH)

This build includes support for Encrypted Client Hello (ECH), which enhances privacy by encrypting the Server Name Indication (SNI) and other sensitive information in the TLS handshake.

Thanks to [yaroslavros](https://github.com/yaroslavros/nginx/) for the contribution to ECH support.

<details>
<summary>Click to expand details</summary>

### Configuration

#### ssl_ech configuration directive

To enable ECH for a given server configure ssl_ech as follows:
> ssl_ech *public_name* *config_id* *[key=file]* [noretry]

- *public_name* is mandatory. It needs to be set to FQDN to be populated in clear-text SNI of Outer ClientHello. It's highly recommended to have a server block matching that *public_name* and providing a valid certificate for it, otherwise ECH retry mechanism will not work.
- *config_id* is mandatory. It is a number between 0 and 255 identifying ECH configuration. Running multiple configurations with the same id is possible but will reduce performance as server will need to try multiple encryption keys.
- *key=file* is optional. It specifies a *file* with PEM encoded X25519 private key. If it is not specified, key will be generated dynamically on each restart/configuration reload. It is highly recommended to generate and use a static key unless you have DNS automation to update HTTPS DNS record each time new key is generated.
- *noretry* is an optional flag to remove given configuration from retry list or generated ECHConfigList for DNS record. It should be used for historic rotated out keys that may still be used by clients due to caching. Valid configuration requires at least one `ssl_ech` entry without `noretry` flag.

It is possible to have multiple `ssl_ech` configurations in a given server block. `ssl_ech` configurations from multiple server blocks under the same listener will be automatically aggregated. Note that TLS 1.3 must be enabled for `ssl_ech` to be accepted.

#### Generating ECH key

The only KEM supported for ECH in BoringSSL is X25519, HKDF-SHA256, so X25519 key is required. To generate one with OpenSSL run

```sh
openssl genpkey -out ech.key -algorithm X25519
```

#### Populating DNS records

After parsing configuration Nginx will dump encoded ECHConfigList into error_log similarly to

```sh
server ech.example.com ECH config for HTTPS DNS record ech="AEX+DQBB8QAgACBl2nj6LhmbUqJJseiydASRUkdmEQGq/u/e5fXDLsFJSAAEAAEAAQASY2xvdWRmbGFyZS1lY2guY29tAAA="
```

For ECH to work this encoded configuration needs to be added to HTTPS record. Typical HTTPS record looks like this:

```sh
kdig +short crypto.cloudflare.com https
1 . alpn=http/1.1,h2 ipv4hint=162.159.137.85,162.159.138.85 ech=AEX+DQBB8QAgACBl2nj6LhmbUqJJseiydASRUkdmEQGq/u/e5fXDLsFJSAAEAAEAAQASY2xvdWRmbGFyZS1lY2guY29tAAA= ipv6hint=2606:4700:7::a29f:8955,2606:4700:7::a29f:8a55
```

For ECH operation only `ech` is required, other attributes are optional.

</details>

## Warning

All builds are performed through an automated process and follow the latest BoringSSL sources and the latest NGINX mainline version. This repository itself does not check for defects or vulnerabilities in the built NGINX, nor does it provide any guarantees. If you intend to use it in a production environment, please evaluate it yourself.
