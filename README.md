# AWS 


## Introduction

These Terraform scripts will deploy a AWS load balancer, autoscale group, RDS Postgres database with PostGIS extension 
and EC2 Instances to host [Ceeties](https://ceeties.com) Django backend application. 

Then the Ansible playbooks will deploy the Django application.

![Infrastructure Diagram.](https://github.com/kstopa/aws_django/blob/master/files/ELB%20Project.png)

## Not Production Ready

This setup is a nice way of getting an introduction onto how Terraform and Ansible can help deploy your 
Django app. However, it is not something you would want to use in production. For one, any new EC2 
instance will need to be manually configured with Ansible to run the Django app. In terms of security, 
it would be nice to separate the infrastructure to a 3-Tier Architecture.


## Prerequisites

### Set you AWS credentials

You need to set your AWS credentials in your environment.  You can do this by setting the following environment variables:

```bash
export AWS_ACCESS_KEY="your_access_key"
export AWS_SECRET="your_secret_key"
```

Or you can use the AWS CLI to set your credentials.

```bash
aws configure
```


### Install Terraform

On MacOs, you can use Homebrew to install Terraform.

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

For other OS check https://developer.hashicorp.com/terraform/install?product_intent=terraform

### Install Ansible

On MacOS, you can use Homebrew to install Ansible.

```bash
brew install ansible
ansible-galaxy collection install community.general
```

Other OS check https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#control-node-requirements

### Install AWS CLI

On MacOS, you can use Homebrew to install AWS CLI.

```bash
brew install awscli
aws configure
```


### Final review

Before you start the deployment with Terraform and Ansible, make sure again that you have done the following:

1) You have AWS SSH Key pair generated for the EC2 instances
2) AWS cli is working so you can deploy using Terraform
3) You have Terraform installed
4) You have Ansible installed


## Deploy our Load Balancer, ASG, RDS and EC2 Instance with Terraform

Along this process you will use a set of files included in to the `tf` folder. 

1) Create `tf/secret.tfvars` file and set AWS SSH key pair name like so:

```text
db_username = "django"
db_password = "foobarbaz"
db_name = "ceeties"
ami_key_pair_name = "my-ssh-key1"
aws_region = "us-west-1"
django_secret_key="YOUR_DJANGO_SECRET_KEY"
django_settings_module="dj_ceeties.settings.production"
```

2) Review `mian.tf` file. You may consider to set different instance types, volume sizes, etc. 
Finally, you can check the plan with:

>terraform init

> terraform plan -var-file="secret.tfvars"

3) If everything looks good on the output and no errors are produced you can deploy via Terraform.

> terraform init -upgrade

> terraform apply -var-file="secret.tfvars"

Note the output value "clb_dns_name" which is the load balancer DNS name for the application.

4) Get Instance Public IP Address using ASG "name"
We need the public IP address of the EC2 instance in our autoscale group.  Use the autoscaling group name in the command below to get it's public IP Address (or get it by logging into AWS - EC2).

> sh aws-asg-instances-ip.sh

----------------------------------------------
## Run Ansible to deploy a Django app

Set these values in the Ansible 'ansible/hosts.tpl' file:

1. EC2 instance public IPs - "hosts".
2. Set SSH key file path and filename - ansible_ssh_private_key_file.
3. Set "clb_dns_name" to load balancer public domain name.
4. Set "aws_db_dns_name" to load balancer public domain name.
5. Set "aws_db_username" and "aws_db_password"


### Setup your vars

Create a new file at `ansible/hosts` from the template at `ansible/hosts.tpl` and set the the variables that you get
after running Terraform script.
 
### Get you app code

First set the path of your Django app. For an quick example django app you can clone 
[Django Hitcount](https://github.com/thornomad/django-hitcount) app.

```bash
export DJANGO_APP_PATH="/path/to/your/django/app"
export CURRENT_PATH=$(pwd)
cd $DJANGO_APP_PATH 
zip -r $CURRENT_PATH/django-app.zip ./* -x "*/\.*" -x "./devops/*" -x "./data/*" -x "*/__pycache__/*" -x "*/migrations/*"
cd $CURRENT_PATH
```

### Run Ansible playbooks

Now run Ansible playbooks below:

```bash
cd ansible
ansible-playbook -i hosts deploy.yaml
ansible-playbook -i hosts config_files.yaml
```

#### (Optional) SSL certificate

If you set your server to work at 443 port you should setup Let's Encript SSL certificate (or other by hand)/

**First setup your DNS records** to point your domain the node balancer by addint an 'A' record to it.
Then you can setup SSL certificate with Certbot by running:

```bash
ansible-playbook -i hosts certbot_ssl.yaml
```

## Go to Load Balancer endpoint

You should now be able to visit the load balancer endpoint and see your Django App working.
It may take a minute for the load balancer to health check the instance and process requests correctly.

## Final touches

Add a django admin user. Connect to any EC2 instance and run:

```
cd /var/www/django-app
. ../venv/bin/activate
python ./manage.py createsuperuser
```

To install ollama:

```
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama2
```

## Clean up

> terraform destroy -var-file="secret.tfvars"

## Troubleshuting 

If something goes wrong you can login on any EC2 instnace by using ssh:

```
ssh -i path/yo/your/certificate.pem ubuntu@IP.ADD.EC2.INS
```

Then you can check jurnaling logs with:

```
# UWSGI
systemctl status uwsgi.service
# Nginx
systemctl status nginx.service
```

Or the django app log at with:

```
sudo vim /var/log/uwsgi/app/example_project.log
```

## License

This project is a fork of the [AWS Django project](https://github.com/jose-guevarra/aws_django) and adapted for the 
Ceeties backend application by [OD.C](https://opendev.consulting).

For additional documentation, see the post [Deploy Django on AWS with Terraform and Ansible](https://dataonfire.medium.com/deploy-django-on-aws-with-terraform-and-ansible-part-1-f2eb49b00753).
