#!/bin/bash

#@todo - command args for region and asg id

# Set your region
export REGION=us-east-2

for ID in $(aws autoscaling describe-auto-scaling-instances --region $REGION --query AutoScalingInstances[].InstanceId --output text);
do


aws ec2 describe-instances --instance-ids $ID --region $REGION --query Reservations[].Instances[].PublicIpAddress --output text
done
