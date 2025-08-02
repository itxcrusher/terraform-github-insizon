#!/bin/bash
environment="$1"

echo "About to run terraform plan"
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
terraform init
sleep 1

# terraform force-unlock -force "c6d863a2-3588-22af-8fbd-c5dab53c7477"
terraform plan -var-file="./env/$environment.tfvars"