#! /usr/bin/bash

while getopts p:k:h:d flag
do
    case "$flag" in
        p) projectName=${{OPTARG}};;
        k) publicKey=${{OPTARG}};;
        h) hostName=${OPTARG};;
        d) docker=True;;
    esac
done

# Installing Nodejs
sudo apt update
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt-get install -y nodejs

# Installing global node packages
sudo npm i -g pm2 yarn typescript

# Installing and setup Nginx
sudo apt install nginx
sudo systemctl restart nginx
sudo apt install certbot python3-certbot-nginx

# Installing Docker
if [[ docker == True ]]
then
    sudo apt install apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    apt-cache policy docker-ce
    sudo apt install docker-ce
    mkdir -p ~/.docker/cli-plugins/
    curl -SL https://github.com/docker/compose/releases/download/v2.3.3/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose
fi

# authorized_keys2 Setup
ehco "$publicKey" > ~/.ssh/authorized_keys2
sudo sed -i 's:AuthorizedKeysFile\t.ssh/authorized_keys:AuthorizedKeysFile\t.ssh/authorized_keys\t.ssh/authorized_keys2:' /etc/ssh/sshd_config

serverFile=$( cat <<EOF
server {
    root /home/ubuntu
    # root /home/ubuntu/$projectName/build;
    index index.html index.htm index.nginx-debian.html;
    
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
    
    
    # location / {
    #     proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
    #     proxy_pass http://localhost:4000/;
    #     proxy_http_version 1.1;
    #     proxy_set_header Upgrade \$http_upgrade;
    #     proxy_set_header Connection 'upgrade';
    #     proxy_set_header X-Real-IP \$remote_addr;
    #     proxy_set_header Host \$host;
    #     proxy_cache_bypass \$http_upgrade;
    # }
    
    # location /socket.io/ {
    #     proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    
    #     proxy_pass http://localhost:5000/socket.io/;
    #     proxy_http_version 1.1;
    #     proxy_set_header Upgrade \$http_upgrade;
    #     proxy_set_header Connection 'upgrade';
    #     proxy_set_header X-Real-IP \$remote_addr;
    #     proxy_set_header Host \$host;
    #     proxy_cache_bypass \$http_upgrade;
    # }
    
    # location / {
    #     try_files \$uri /index.html;
    #     add_header Cache-Control "no-store, no-cache, must-revalidate";
    # }
    
    
    #For static files
    # location /static {
    #     alias /home/ubuntu/$projectName/build/static/;
    #     expires 1y;
    #     add_header Cache-Control "public";
    #     access_log off;
    # }
}
EOF
)

sudo echo "$serverFile" > /etc/nginx/sites-available/$hostName
sudo ln -s /etc/nginx/sites-available/$hostName /etc/nginx/sites-enabled/

htmlFile=$( cat <<EOF
<html>
 <head>
 </head>
 <body>
   <h1>Hello World<h1>
 </body>
</html>
EOF
)

echo "$htmlFile" > index.html

sudo certbot --nginx -d $hostName --non-interactive --agree-tos

rm index.html

sudo sed -i 's:root /home/ubuntu::' /etc/nginx/sites-available/$hostName

mkdir temp $projectName