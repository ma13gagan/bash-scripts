#! /usr/bin/bash

# Exit when any command fails
set -e

while getopts h:s: flag
do
    case "$flag" in
        h) hostName=${OPTARG};;
        s) serverType=${OPTARG};;
    esac
done

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
