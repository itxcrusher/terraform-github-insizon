#!/bin/bash
environment="dev"

echo "About to run terraform plan"
sleep 1

echo "Changing to root directory"
cd ".."

echo "About to push to Github"
sleep 1
git add .
git commit -m "Working hard"
git push


echo "Changing to root directory"
cd "../shell"