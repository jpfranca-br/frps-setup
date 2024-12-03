#!/bin/bash

# Prompt user for email
read -p "Enter your email address (for Certbot notifications): " user_email

# Prompt user for domains
read -p "Enter the number of domains: " n
domains=()
for ((i=1; i<=n; i++)); do
    read -p "Enter domain $i: " domain
    domains+=("$domain")
done

# Prompt user for the FRP token
read -p "Enter the FRP token: " frp_token

# Get the current username
username=$(whoami)

# Change folder to the user's home directory
cd /home/$username

# Update and install dependencies
sudo apt-get update -y
sudo apt-get install apt-utils ufw certbot python3-certbot-nginx -y
sudo apt-get upgrade -y

# Test and reload Nginx
sudo nginx -t
sudo systemctl reload nginx

# Prepare Certbot domain arguments
certbot_domains=""
nginx_server_name=""
for domain in "${domains[@]}"; do
    certbot_domains="$certbot_domains -d $domain"
    nginx_server_name="$nginx_server_name $domain"
done

# Obtain SSL certificates
sudo certbot --nginx $certbot_domains --non-interactive --agree-tos --email $user_email

# Test and dry-run renew
sudo certbot renew --dry-run

# Create/rewrite /etc/nginx/sites-available/default
nginx_config="/etc/nginx/sites-available/default"
sudo bash -c "cat > $nginx_config" <<EOL
server {
    $(for domain in "${domains[@]}"; do
        echo "if (\$host = $domain) {"
        echo "    return 301 https://\$host\$request_uri;"
        echo "} # managed by Certbot"
        echo
    done)

    listen 80;
    server_name$nginx_server_name;
    # Redirect all HTTP traffic to HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name$nginx_server_name;

    ssl_certificate /etc/letsencrypt/live/${domains[0]}/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/${domains[0]}/privkey.pem; # managed by Certbot

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Proxy all requests to localhost:8080
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Reload Nginx
sudo nginx -t
sudo systemctl reload nginx

# Install and configure FRP
wget https://github.com/fatedier/frp/releases/download/v0.61.0/frp_0.61.0_linux_amd64.tar.gz
tar -xzvf frp_0.61.0_linux_amd64.tar.gz
rm -rf frp
mv frp_0.61.0_linux_amd64 frp
rm -rf frp_0.61.0_linux_amd64.tar.gz

# Create/rewrite ~/frp/frps.toml
cat > /home/$username/frp/frps.toml <<EOL
# frps.toml
bindPort = 7000
vhostHTTPPort = 8080
auth.method = "token"
auth.token = "$frp_token"
EOL

# Create/rewrite /etc/systemd/system/frps.service
sudo bash -c "cat > /etc/systemd/system/frps.service" <<EOL
[Unit]
Description=FRP Server
After=network.target

[Service]
ExecStart=/home/$username/frp/frps -c /home/$username/frp/frps.toml
Restart=always
RestartSec=5
User=$username
WorkingDirectory=/home/$username/frp

[Install]
WantedBy=multi-user.target
EOL

# Enable and start FRP service
sudo systemctl daemon-reload
sudo systemctl enable frps.service
sudo systemctl start frps.service

# Configure UFW
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 7000
echo "y" | sudo ufw enable

echo "Setup complete for domains: ${domains[*]}"
