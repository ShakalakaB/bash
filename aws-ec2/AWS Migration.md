# AWS Migration Steps

----

✈️ Step
+ Set up AWS EC2, RDS in AWS GUI console
+ New EC2 > Turn on port 80 in EC2 security
+ Run `bash/aws-ec2/ec2-config.sh` to install dependencies
+ Copy generated GitHub ssh key from last step into GitHub
+ Migrate DB with `bash/aws-ec2/mysql-export.sh` and `bash/aws-ec2/mysql-import.sh`
+ Change DB setting in respective projects
+ Old EC2 > push git repo changes
+ New EC2 > Clone git repo > run project
+ New EC2 > Set up Nginx conf file with `bash/nginx/`
+ Cloudflare > Change ip
+ New EC2 > Run `certbot` to set up domain
