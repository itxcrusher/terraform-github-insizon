#!/bin/bash
# bash apply.sh vs source apply.sh
environment="$1"

echo "About to run terraform apply"
sleep 1

echo "Changing to root directory"
cd "../src"

echo "About to delete .terraform folder"
rm -rf "./terraform"
sleep 1


echo "About to formate code"
terraform fmt -recursive
sleep 1

echo "About to source project"
source ".env"
sleep 1

echo "About to create .terraform folder"
terraform init -upgrade
sleep 1


terraform apply -var-file="./env/$environment.tfvars" -auto-approve

echo "Change back to shell dir"
cd "../shell/"
sleep 1