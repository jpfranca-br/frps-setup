# FRPS Server Configuration Script

This script is designed to configure and set up an [FRPS (Fast Reverse Proxy Server)](https://github.com/fatedier/frp/blob/dev/conf/frps_full_example.toml) environment on a clean Ubuntu Linux server. It automates the process of configuring the server for domain-based reverse proxying and security using Let's Encrypt SSL certificates and FRP.

## Prerequisites

Before running this script, ensure you have:

1. A domain with DNS configured:
   - Create an **A record** in your DNS zone to point your server's name and the internal service(s) you want to access to a fixed public IP address.

   For the rest of this tutorial, let's assume:
   - Server: `server.foobar.com`
   - Internal service: `internal_service_name.foobar.com`

2. Access to a Linux server with su privileges.

---

## Steps for Configuration

### 1. Log in as root and create a new user for the FRPS service

Run the following commands to create a user (we will use `foobar` in this example):

```bash

ssh root@server.foobar.com
adduser foobar
usermod -aG sudo foobar
exit

```

### 2. Log in as the new user

Log in as the newly created user:

```bash

ssh foobar@server.foobar.com

```

### 3. Download and execute the setup script

Download setup.sh and execute it:

```bash
wget -O frps-setup.sh https://github.com/jpfranca-br/frps-setup/raw/refs/heads/main/frps-setup.sh && chmod +x frps-setup.sh && ./frps-setup.sh
```

### 4. Enter the required data

The script will prompt you to enter the following information:

- **Email Address**: Used for Certbot notifications.
- **Number of Domains**: The number of domains you want to configure.
- **Domain Names**: Enter each domain name one by one.
- **FRP Token**: Enter a secure token that will later be used by FRP clients to authenticate.
- **password**: Enter the password for the currently logged user

#### Example Inputs:

```text
Enter your email address (for Certbot notifications): foobar@foobar.com
Enter the number of domains: 2
Enter domain 1: server.foobar.com
Enter domain 2: internal_service_name.foobar.com
Enter the FRP token: abc-def-ghi-jkl
[sudo] password for foobar:
```

### 5. Wait for the script to complete

The script will perform all necessary configurations and display the following message upon successful completion:

```text
Setup complete for domains: server.foobar.com internal_service_name.foobar.com
```

That’s all you need to do on the server side!

---

## Client Configuration

For each client, configure the `frpc.toml` file as follows:

```toml
# frpc.toml
user = "foobar"

loginFailExit = false

serverAddr = "server.foobar.com" 
serverPort = 7000

auth.method = "token"
auth.token = "abc-def-ghi-jkl" 
# Use the token entered during server setup.

[[proxies]]
name = "internal_service_name" # Descriptive name for your service
type = "http"
localPort = 8096               # Internal port of your service
customDomains = ["internal_service_name.foobar.com"]
```

---

## What the Script Does

1. **System Updates and Dependencies**: Installs required packages such as `certbot`, `nginx`, and `apt-utils`.
2. **SSL Configuration**: Obtains Let's Encrypt certificates for the specified domains.
3. **Nginx Configuration**: Configures Nginx to proxy traffic securely to internal services.
4. **FRP Setup**:
   - Downloads and configures the FRP server.
   - Generates a secure `frps.toml` file.
   - Creates and enables the FRP service.

---

## Troubleshooting

- **Domain Resolution Issues**: Ensure your DNS A records are correctly configured to point to the server's IP.
- **Port Accessibility**: Ensure the necessary ports (22, 80, 443, 7000) are open on your server's firewall.
- **SSL Certificate Issues**: Check that your domains resolve correctly and Certbot can verify ownership.

---

## Credits

This script simplifies the process of setting up a secure FRP server environment. For more details about FRP, visit the [official FRP GitHub repository](https://github.com/fatedier/frp).
