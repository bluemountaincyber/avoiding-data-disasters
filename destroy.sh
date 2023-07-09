#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
NOCOLOR="\033[0m"

BUCKET=$(aws s3 ls | grep sensitive | awk '{print $3}')
echo -en $GREEN"Emptying $BUCKET bucket... "$NOCOLOR
aws s3api put-bucket-versioning --bucket $BUCKET --versioning-configuration Status=Suspended
for OBJECT in $(aws s3api list-object-versions --bucket $BUCKET | jq -r '"\(.DeleteMarkers[].Key),\(.DeleteMarkers[].VersionId)"'); do
  KEY=$(echo $OBJECT | cut -d ',' -f1)
  VERSIONID=$(echo $OBJECT | cut -d ',' -f2)
  aws s3api delete-object --bucket $BUCKET --version-id $VERSIONID --key $KEY 2>/dev/null >/dev/null
done
for OBJECT in $(aws s3api list-object-versions --bucket $BUCKET | jq -r '"\(.Versions[].Key),\(.Versions[].VersionId)"'); do
  KEY=$(echo $OBJECT | cut -d ',' -f1)
  VERSIONID=$(echo $OBJECT | cut -d ',' -f2)
  aws s3api delete-object --bucket $BUCKET --version-id $VERSIONID --key $KEY 2>/dev/null >/dev/null
done
if ! [[ $(aws s3 ls s3://$BUCKET/customers.csv) ]]; then
    echo "Done"
else
    echo -e $RED"FAILED"$NOCOLOR
    exit 1
fi

echo -en $GREEN"Destroying CloudFormation stack... "$NOCOLOR
aws cloudformation delete-stack --stack-name avoiding-data-disasters
while true; do
    if [[ $(aws cloudformation describe-stacks --query 'Stacks[?StackName==`avoiding-data-disasters`].StackName' --output text) == "avoiding-data-disasters" ]]; then
        sleep 5
    else
        echo "Done"
        break
    fi
done
