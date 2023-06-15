#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
NOCOLOR="\033[0m"

BUCKET=$(aws s3 ls | grep sensitive | awk '{print $3}')
echo -en $GREEN"Emptying sensitive-$BUCKET bucket... "$NOCOLOR
aws s3 rm --recursive s3://$BUCKET

echo -en $GREEN"Destroying CloudFormation stack... "$NOCOLOR
aws cloudformation delete-stack --stack-name avoiding-data-disasters --profile cloudtools
echo "Done"
