# AWS 


## Introduction

These Terraform scripts will deploy a AWS load balancer, autoscale group, and EC2 Instance to 
host [Ceeties](https://ceeties.com) Django application. Then the Ansible playbooks will deploy 
the Django application.

![Infrastructure Diagram.](./files/ELB Project.png)



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
```

Other OS check https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#control-node-requirements

### Install AWS CLI

On MacOS, you can use Homebrew to install AWS CLI.

```bash
brew install awscli
```



## Assumptions

1) You have AWS SSH Key pair generated for the EC2 instances
2) AWS cli is working so you can deploy using Terraform
3) You have Terraform installed
4) You have Ansible installed


## Use Terraform to deploy our Load Balancer, ASG, and EC2 Instance

1) Create tf/secret.tfvars file and set AWS SSH key pair name like so:

db_username = "django"
db_password = "foobarbaz"
ami_key_pair_name = "my-ssh-key1"
aws_region = "us-west-1"

2) Check the plan

> terraform init
> terraform plan -var-file="secret.tfvars"

2) Deploy via Terraform.


> terraform init -upgrade
> terraform apply -var-file="secret.tfvars"

Note the output value "clb_dns_name" which is the load balancer DNS name for the application.

3) Get Instance Public IP Address using ASG "name"
We need the public IP address of the EC2 instance in our autoscale group.  Use the autoscaling group name in the command below to get it's public IP Address (or get it by logging into AWS - EC2).

> sh aws-asg-instances-ip.sh


## Run Ansible to deploy Django-hitcount app

Set these values in the Ansible "hosts" file:
1. EC2 instance public IPs - "hosts".
2. Set SSH key file path and filename - ansible_ssh_private_key_file.
3. Set "clb_dns_name" to load balancer public domain name.
4. Set "aws_db_dns_name" to load balancer public domain name.
5. Set "aws_db_username" and "aws_db_password"

NOTE: The django-hitcount/ directory has the app source code.  You can apply updates then you need to create a new django-hitcount.tar.gz file to upload to changes to the app.
 
tar -czvf django-hitcount.tar.gz django-hitcount/

Now run Ansible playbooks below:

> ansible-playbook -i hosts deploy.yaml
>
> ansible-playbook -i hosts config_files.yaml

## Go to Load Balancer endpoint

You should now be able to visit the load balancer endpoint and see a Ceeties backend working. 
It may take a minute for the load balancer to health check the instance and process requests correctly.

## Clean up

> terraform destroy -var-file="secret.tfvars"

## License

This project is a fork of the [AWS Django project](https://github.com/jose-guevarra/aws_django) and adapted for the Ceeties Django application by [OD.C](https://opendev.consulting).
For additional documentation, see the post [Deploy Django on AWS with Terraform and Ansible](https://dataonfire.medium.com/deploy-django-on-aws-with-terraform-and-ansible-part-1-f2eb49b00753).