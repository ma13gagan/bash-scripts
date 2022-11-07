#! /usr/bin/bash

# Exit when any command fails
set -e

# Keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# Echo an error message before exiting
trap 'print_messages "\"${last_command}\" command failed with exit code $?." 1' EXIT

while getopts p:h:s:d flag
do
    case "$flag" in
        p) projectName=${OPTARG};;
        h) hostName=${OPTARG};;
        s) serverType=${OPTARG};;
        d) docker=True;;
    esac
done

# Initial server setup
sudo apt update
sudo apt install curl zip unzip -y
print_messages "Initial server setup completed"

# Installing Nodejs
sudo apt update
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
print_messages "Nodejs installed"

# Installing global node packages
sudo npm i -g pm2 yarn typescript
print_messages "Global packages installed"

# Installing and setup Nginx
sudo apt install nginx -y
sudo systemctl restart nginx
sudo apt install certbot python3-certbot-nginx -y
print_messages "Nginx setup completed"

# Installing Docker
if [[ $docker == True ]]
then
    sudo apt install apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    apt-cache policy docker-ce
    sudo apt install docker-ce -y
    mkdir -p ~/.docker/cli-plugins/
    curl -SL https://github.com/docker/compose/releases/download/v2.3.3/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose
    print_messages "Docker setup completed"
fi

rpServerFile=$( cat <<EOF
server {
    server_name $hostName;
    
    # X-Frame-Options is to prevent from clickJacking attack
    add_header X-Frame-Options SAMEORIGIN;
    # disable content-type sniffing on some browsers.
    add_header X-Content-Type-Options nosniff;
    # This header enables the Cross-site scripting (XSS) filter
    add_header X-XSS-Protection "1; mode=block";
    # This will enforce HTTP browsing into HTTPS and avoid ssl stripping attack
    add_header Strict-Transport-Security "max-age=31536000; includeSubdomains;";
    add_header Referrer-Policy "no-referrer-when-downgrade";
    
    
    location / {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
        proxy_pass http://localhost:4000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/$hostName/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/$hostName/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}
server {
    if (\$host = $hostName) {
        return 301 https://\$host\$request_uri;
    } # managed by Certbot



    server_name $hostName;
    listen 80;
    return 404; # managed by Certbot
}
EOF
)

staticServerFile=$( cat <<EOF
server {
    root ~/$projectName/build;
    index index.html index.htm index.nginx-debian.html;
    
    server_name $hostName;
    
    location / {
        try_files \$uri /index.html;
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }
    
    
    For static files
    location /static {
        alias ~/$projectName/build/static/;
        expires 1y;
        add_header Cache-Control "public";
        access_log off;
    }

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/$hostName/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/$hostName/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}
server {
    if (\$host = $hostName) {
        return 301 https://\$host\$request_uri;
    } # managed by Certbot



    server_name $hostName;
    listen 80;
    return 404; # managed by Certbot
}
EOF
)

sudo certbot --nginx -d $hostName --agree-tos --register-unsafely-without-email

if [[ serverType == "node" ]]
then
    echo "$rpServerFile" > /tmp/$hostName
else
    echo "$staticServerFile" > /tmp/$hostName
fi

sudo mv -r /tmp/$hostName /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/$hostName /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

print_messages "SSL setup completed"

mkdir ~/temp ~/$projectName

print_messages "Whole Server Setup Completed! Enjoy!!!" 2