#!/bin/bash

echo "🤖================>  Install git"
sudo yum install git-2.40.1

echo "🤖================>  Install Nginx"
sudo yum install nginx-1.22.1
sudo systemctl start nginx.service

echo "🤖================>  Install nvm(node)"
sudo curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 18.20.3
export NVM_DIR="$HOME/.nvm"
# This loads nvm
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# This loads nvm bash_completion
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

echo "🤖================>  Enable Corepack"
sudo npm update corepack -g
corepack enable

echo "🤖================>  Install Docker"
sudo yum install docker-25.0.3

echo "🤖================>  Install docker-compose"
sudo curl -L https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
# Start docker
systemctl start docker

echo "🤖================>  Install certbot"
sudo dnf install -y augeas-libs
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot

echo "🤖================>  Install crontab"
sudo yum install cronie
sudo systemctl start crond.service
sudo systemctl enable crond.service

# Choose download package from "https://dev.mysql.com/downloads/"
echo "🤖================>  Install MySQL client"
sudo yum install -y https://dev.mysql.com/get/mysql84-community-release-el9-1.noarch.rpm
sudo yum install -y mysql-community-client

# Install pm2
echo "🤖================> Install MySQL client"
sudo yarn global add pm2@5.4.2

# set github ssh key
echo "🤖================> Set github ssh key"
ssh-keygen -t ed25519 -C "rakihubo@gmail.com" -f "/root/.ssh/github-raki" -N ""
ssh-keygen -t ed25519 -C "aldora988@gmail.com" -f "/root/.ssh/github-aldora" -N ""

# create ssh/config file
echo "🤖================> Create ssh/config file"
cp ./config /root/.ssh/

# set up nginx: copy and paste nginx.conf
echo "🤖================> Override nginx.conf"
cp ./nginx.conf /etc/nginx/nginx.conf

# Add crontab job: auto renew domain certs
#todo: change the 'ec2-xx'
echo "🤖================>  Add crontab job"
(crontab -l; echo '0 0 */3 * * certbot -q renew && curl -fsS https://hc-ping.com/07b9ddd2-9b38-4a78-854f-89af632495c4 -d "message=ec2-xx') | crontab -
