#!/bin/bash

echo "===> Install git"
sudo yum install git-2.39.2

echo "===> Install Nginx"
sudo yum install nginx-1.22.1
sudo systemctl start nginx.service

echo "===> Install nvm(node)"
sudo curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 18.20.3

echo "===> Enable Corepack"
sudo npm update corepack -g
corepack enable

echo "===> Install Docker"
sudo yum install docker-20.10.17

echo "===> Install docker-compose"
sudo curl -L https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo "===> Install certbot"
sudo dnf install -y augeas-libs
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot


echo "===> Install crontab"
sudo yum install cronie
sudo systemctl start crond.service
sudo systemctl enable crond.service

# Choose download package from "https://dev.mysql.com/downloads/"
echo "===> Install MySQL client"
sudo yum install -y https://dev.mysql.com/get/mysql84-community-release-el9-1.noarch.rpm
sudo yum install -y mysql-community-client


