#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
NOCOLOR="\033[0m"

pushd ~/avoiding-data-disasters >/dev/null
echo -en $GREEN"Deploying CloudFormation stack... "$NOCOLOR
aws cloudformation create-stack --stack-name avoiding-data-disasters --template-body file://TotallySecure.yaml >/dev/null
while true; do
    case $(aws cloudformation describe-stacks --stack-name avoiding-data-disasters --query 'Stacks[].StackStatus' --output text) in
        CREATE_COMPLETE)
            echo "Done"
            break
            ;;
        CREATE_FAILED)
            echo -e $RED"FAILED"
            exit 1
            ;;
        CREATE_IN_PROGRESS)
            sleep 5
            ;;
        *)
            echo -e $RED"FAILED"$NOCOLOR
            exit 1
            ;;
    esac
done

echo -en $GREEN"Setting bucket ACL... "$NOCOLOR
BUCKET=$(aws s3 ls | grep sensitive- | awk '{print $3}')
aws s3api put-bucket-acl --bucket $BUCKET --acl public-read >/dev/null
if [[ $(aws s3api get-bucket-acl --bucket $BUCKET --query 'Grants[?Permission==`READ`].Grantee.URI' --output text) == "http://acs.amazonaws.com/groups/global/AllUsers" ]]; then
    echo "Done"
else
    echo $RED"FAILED"$NOCOLOR
    exit 1
fi

echo -en $GREEN"Uploading sensitive data... "$NOCOLOR
aws s3 cp customers.csv s3://$BUCKET/customers.csv >/dev/null
popd >/dev/null
aws s3 ls s3://$BUCKET/customers.csv >/dev/null
if [ $? -eq 0 ]; then
    echo "Done"
else
    echo -e $RED"FAILED"$NOCOLOR
    exit 1
fi
