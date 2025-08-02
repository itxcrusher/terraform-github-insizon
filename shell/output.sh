#!/bin/bash
environment="dev"

echo "About to run terraform output"
sleep 1

echo "Changing to root directory"
cd "../src"


terraform output -raw my_output