#!/bin/bash
environment="dev"

echo "About to run terraform plan"
sleep 1

echo "Changing to root directory"
cd "../src"

echo "About to formate code"
terraform fmt -recursive
sleep 1


echo "Changing to shell directory"
cd "../shell"