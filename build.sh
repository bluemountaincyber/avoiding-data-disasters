#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
NOCOLOR="\033[0m"

echo -en $GREEN"Deploying CloudFormation stack... "$NOCOLOR
aws cloudformation create-stack --stack-name avoiding-data-disasters --template-body file://TotallySecure.yaml
echo "Done"

echo -en $GREEN"Uploading sensitive data... "$NOCOLOR
BUCKET=$(aws s3 ls | grep sensitive- | awk '{print $3}')
pushd ~/avoiding-data-disasters
aws s3 cp customers.csv s3://$BUCKET/customers.csv
popd
