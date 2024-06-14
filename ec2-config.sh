#!/bin/bash

echo "===> install git"
sudo yum install git-2.39.2

echo "===> install nginx"
sudo yum install nginx-1.22.1
sudo systemctl start nginx.service

echo "===> install npm"
sudo yum install npm-8.19.2

echo "===> install docker"
sudo yum install docker-20.10.17

echo "===> install docker-compose"
sudo curl -L https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo "===> install certbot"
sudo dnf install -y augeas-libs
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot


echo "===> install crontab"
sudo yum install cronie
sudo systemctl start crond.service
sudo systemctl enable crond.service
