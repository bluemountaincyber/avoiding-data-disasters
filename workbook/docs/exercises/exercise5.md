# Exercise 5: Building an Automated Detection

<!-- markdownlint-disable MD007 MD033-->

<!--Overriding style-->
<style>
  :root {
    --sans-primary-color: #0000ff;
}
</style>

**Estimated Time to Complete:** 20 minutes

## Objectives

- Re-run `s3audit` to show our progress we made in just a few short hours
- Generate a more appropriate CloudFormation template
- Assess the new template with `checkov` to discover any remaining issues

## Challenges

### Challenge 1: Re-Run s3audit

Re-run `s3audit` to see if you've cleaned up all of the findings discovered previously.

??? cmd "Solution"

    1. All of the challenges in this exercise are performed in your **CloudShell** session. Once more, click on the icon near the top-right that looks like a command prompt to start a **CloudShell** session.

        ![](../img/6.png ""){: class="w500" }

    2. So that `s3audit` performs its checks against the correct bucket, use the AWS CLI with its `aws s3api list-buckets` command to gather information about our deployed buckets and then pass that information to the `jq` utility to parse the data and extract the bucket name beginning with the text `sensitive-`.

            ```bash
            BUCKET=$(aws s3api list-buckets | \
              jq -r '.Buckets[] | select(.Name | startswith("sensitive-")) | .Name')
            echo "The bucket to assess is: $BUCKET"
            ```

            !!! summary "Sample result"

                ```bash
                The bucket to assess is: sensitive-012345678910
                ```

    3. You can tell `s3audit` to look at a specific bucket using the `--bucket` flag. Run the command as follows to see the results of your security configuration for your `sensitive-*` bucket.

        ```bash
        s3audit --bucket=$BUCKET
        ```

        !!! summary "Sample result"

            ```bash
            (node:204) NOTE: We are formalizing our plans to enter AWS SDK for JavaScript (v2) into maintenance mode in 2023.

            Please migrate your code to use AWS SDK for JavaScript (v3).
            For more information, check the migration guide at https://a.co/7PzMCcy
            (Use `node --trace-warnings ...` to show where the warning was created)
            ❯ Checking 1 bucket
                ❯ sensitive-206757820151
                ✔ Bucket public access configuration
                    ✔ BlockPublicAcls
                    ✔ IgnorePublicAcls
                    ✔ BlockPublicPolicy
                    ✔ RestrictPublicBuckets
                ✔ Server side encryption is enabled
                ✔ Object versioning is enabled
                ✖ MFA Delete is not enabled
                ✔ Static website hosting is disabled
                ✔ Bucket policy doesn't allow a wildcard entity
                ✔ Bucket ACL doesn't allow access to "Everyone" or "Any authenticated AWS user"
                ✔ Logging is enabled
                ✔ Bucket is not associated with any CloudFront distributions
            ```

    4. MUCH better. In fact, there is only one remaining, availability-related finding left: *MFA Delete is not enabled*. 
    
        !!! note
        
            We will leave this open for now, but feel free to explore how you will enable this in practice if you want to ensure that the bucket owner (you) will need to have MFA enabled to be able to delete any versions of adjust the version state of the bucket. This may mean that the teardown method used in exercise 6 may not work as written.

            More on this [here](https://docs.aws.amazon.com/AmazonS3/latest/userguide/MultiFactorAuthenticationDelete.html).

### Challenge 2: Generate a Better CloudFormation Template

Manually fixing these issues are fine, but if anyone were to reuse even the most recent CloudFormation template (`TotallyMoreSecure.yaml`, which is referenced by the `build-nopublic.sh` script), we will again have those remaining issues - forcing us to redo all of that work all over again. 

Tear down the current deployment, create a new CloudFormation template called `MostSecure.yaml`, and run the build-final.sh script. Afterwards, re-run `s3audit` to ensure that the new deployment met all of the checks that you manually configured previously.

??? cmd "Solution"

    1. Start by running the `` script once more to tear down the current S3 bucket.

        ```bash
        /home/cloudshell-user/avoiding-data-disasters/destroy.sh
        ```

        !!! summary "Sample result"

            ```bash
            Emptying sensitive-012345678910 bucket... Done
            Destroying CloudFormation stack... Done
            ```

    2. We can start with `TotallyMoreSecure.yaml` as a template and build those manual changes that were performed previously to it. Here is what we will begin with:

        !!! summary "Starting point"

            ```yaml
            AWSTemplateFormatVersion: 2010-09-09
            Resources:
              SensitiveBucket:
                Type: AWS::S3::Bucket
                Properties:
                  BucketName: !Join
                    - ''
                    - - 'sensitive-'
                      - !Ref 'AWS::AccountId'
                  OwnershipControls:
                    Rules:
                      - ObjectOwnership: 'BucketOwnerPreferred'
            ```

    3. Next, you will need to add versioning to address availability concerns. To do this, there is a configuration element called `VersioningConfiguration` that must be added. You can learn more about this [here](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-bucket.html#cfn-s3-bucket-versioning) if you'd like. The value of this item should be set to `Status: Enabled` to enforce versioning. Now, our template looks like this:

        !!! summary "Starting point"

            ```yaml
            AWSTemplateFormatVersion: 2010-09-09
            Resources:
              SensitiveBucket:
                Type: AWS::S3::Bucket
                Properties:
                  BucketName: !Join
                    - ''
                    - - 'sensitive-'
                      - !Ref 'AWS::AccountId'
                  OwnershipControls:
                    Rules:
                      - ObjectOwnership: 'BucketOwnerPreferred'
                  VersioningConfiguration:
                    Status: Enabled 
            ```

    4. Now, for the access logging. This one is a bit more cumbersome as we will need to add the `LoggingConfiguration` element and reference a bucket name dynamically (just like the original code does for the `sensitive-` bucket) as it will be different for each workshop participant. As noted [here](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-bucket-loggingconfig.html), we need to reference a `DestinationBucketName` which is our `security-` bucket. This makes our template read as follows:

        !!! summary "Starting point"

            ```yaml
            AWSTemplateFormatVersion: 2010-09-09
            Resources:
              SensitiveBucket:
                Type: AWS::S3::Bucket
                Properties:
                  BucketName: !Join
                    - ''
                    - - 'sensitive-'
                      - !Ref 'AWS::AccountId'
                  OwnershipControls:
                    Rules:
                      - ObjectOwnership: 'BucketOwnerPreferred'
                  VersioningConfiguration:
                    Status: Enabled
                  LoggingConfiguration:
                    DestinationBucketName: !Join
                      - ''
                      - - 'security-'
                        - !Ref 'AWS::AccountId'
            ```

    5. While we're at it, let's make sure that the block public access settings are in place just in case some defaults were to change in the future (and also to make some assessment tools happy). In this case, the `PublicAccessBlockConfiguration` must be included as noted [here](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-bucket.html#cfn-s3-bucket-publicaccessblockconfiguration). We should include all four options (`BlockPublicAcls`, `BlockPublicPolicy`, `IgnorePublicAcls`, `RestrictPublicBuckets`) and set them to `true`. That will leave us with this:

        !!! summary "Starting point"

            ```yaml
            AWSTemplateFormatVersion: 2010-09-09
            Resources:
              SensitiveBucket:
                Type: AWS::S3::Bucket
                Properties:
                  BucketName: !Join
                    - ''
                    - - 'sensitive-'
                      - !Ref 'AWS::AccountId'
                  OwnershipControls:
                    Rules:
                      - ObjectOwnership: 'BucketOwnerPreferred'
                  VersioningConfiguration:
                    Status: Enabled
                  LoggingConfiguration:
                    DestinationBucketName: !Join
                      - ''
                      - - 'security-'
                        - !Ref 'AWS::AccountId'
                  PublicAccessBlockConfiguration:
                    BlockPublicAcls: true
                    BlockPublicPolicy: true
                    IgnorePublicAcls: true
                    RestrictPublicBuckets: true
            ```

    6. To generate this bucket, we must first create a new file with this YAML content. Use the following heredoc to write the YAML content to `/home/cloudshell-user/avoiding-data-disasters/MostSecure.yaml`.

        ```bash
        cat <<EOF > /home/cloudshell-user/avoiding-data-disasters/MostSecure.yaml
        AWSTemplateFormatVersion: 2010-09-09
        Resources:
          SensitiveBucket:
            Type: AWS::S3::Bucket
            Properties:
              BucketName: !Join
                - ''
                - - 'sensitive-'
                  - !Ref 'AWS::AccountId'
              OwnershipControls:
                Rules:
                  - ObjectOwnership: 'BucketOwnerPreferred'
              VersioningConfiguration:
                Status: Enabled
              LoggingConfiguration:
                DestinationBucketName: !Join
                  - ''
                  - - 'security-'
                    - !Ref 'AWS::AccountId'
              PublicAccessBlockConfiguration:
                BlockPublicAcls: true
                BlockPublicPolicy: true
                IgnorePublicAcls: true
                RestrictPublicBuckets: true
        EOF
        ```

    7. And now, the moment of truth! Run `build-final.sh` to deploy this new, much more secure S3 bucket.

        ```bash
        /home/cloudshell-user/avoiding-data-disasters/build-final.sh
        ```

        !!! summary "Sample result"

            ```bash
            Deploying CloudFormation stack one last time... Done
            Uploading sensitive data... Done
            ```

### Challenge 3: Assess New Template With checkov

There was a lot of building, finding issues with an assessment tool, tearing down, adjusting code, and repeating of this process throughout the workshop... but there's a better way to get in front of these issues - even before deploying ANYTHING. So, to "shift security left", analyze the original and final CloudFormation templates to see how an assessment tool can inform us of what possible security issues would arise had we deployed this Infrastructure as Code (IaC).

The security tool you can use is **Checkov**. This tool is not installed in **AWS CloudShell**, so you will need to get it up and running before you can assess the `TotallySecure.yaml` and `MostSecure.yaml` files.

??? cmd "Solution"

    1. To begin, you must first install **Checkov**. Since **Checkov** is a tool written in Python, you can set up a virtual environment in your `/home/cloudshell-user/avoiding-data-disasters` directory and install it using `pip`, like so:

        ```bash
        cd /home/cloudshell-user/avoiding-data-disasters
        python3 -m venv .venv
        source .venv/bin/activate
        pip install checkov
        ```

        !!! summary "Sample result"

            ```bash
            <snip>

            0.7.5 update-checker-0.18.0 uritools-4.0.1 urllib3-1.26.16 wcwidth-0.2.6 websocket-client-1.6.1 xmltodict-0.13.0 yarl-1.9.2 zipp-3.15.0
            WARNING: You are using pip version 22.0.4; however, version 23.1.2 is available.
            You should consider upgrading via the '/home/cloudshell-user/avoiding-data-disasters/.venv/bin/python3 -m pip install --upgrade pip' command.
            ```

    2. To ensure that **Checkov** was installed properly and to see what options it has, you can run the following:

        ```bash
        checkov --help
        ```

        !!! summary "Sample result"

            ```bash
            usage: checkov [-h] [-v] [--support] [-d DIRECTORY] [--add-check]
               [-f FILE [FILE ...]] [--skip-path SKIP_PATH]
               [--external-checks-dir EXTERNAL_CHECKS_DIR]
               [--external-checks-git EXTERNAL_CHECKS_GIT] [-l]
               [-o {cli,csv,cyclonedx,cyclonedx_json,json,junitxml,github_failed_only,gitlab_sast,sarif,spdx}]
               [--output-file-path OUTPUT_FILE_PATH] [--output-bc-ids]
               [--include-all-checkov-policies] [--quiet] [--compact]

            <snip>

              --openai-api-key OPENAI_API_KEY
                        Add an OpenAI API key to enhance finding guidelines by
                        sending violated policies and resource code to OpenAI
                        to request remediation guidance. This will use your
                        OpenAI credits. Set your number of findings that will
                        receive enhanced guidelines using
                        CKV_OPENAI_MAX_FINDINGS [env var: CKV_OPENAI_API_KEY]

            Args that start with '--' can also be set in a config file (/home/cloudshell-
            user/avoiding-data-disasters/.checkov.yaml or /home/cloudshell-user/avoiding-
            data-disasters/.checkov.yml or /home/cloudshell-user/.checkov.yaml or
            /home/cloudshell-user/.checkov.yml or specified via --config-file). The config
            file uses YAML syntax and must represent a YAML 'mapping' (for details, see
            http://learn.getgrav.org/advanced/yaml). In general, command-line values
            override environment variables which override config file values which
            override defaults.
            ```

    3. That is quite verbose. You may notice that this tool supports a large variety of IaC offerings, including CloudFormation. It is even smart enough, in most cases, to understand the IaC product it is testing, so we can just use the `--file` flag to target our original and most secure CloudFormation template files. Let's start with `TotallySecure.yaml`.

        ```bash
        checkov --file /home/cloudshell-user/avoiding-data-disasters/TotallySecure.yaml
        ```

        !!! summary "Sample result"

            ```bash
            <snip>

            Check: CKV_AWS_56: "Ensure S3 bucket has 'restrict_public_bucket' enabled"
            FAILED for resource: AWS::S3::Bucket.SensitiveBucket
            File: /TotallySecure.yaml:3-17
            Guide: https://docs.paloaltonetworks.com/content/techdocs/en_US/prisma/prisma-cloud/prisma-cloud-code-security-policy-reference/aws-policies/s3-policies/bc-aws-s3-22.html

                    3  |   SensitiveBucket:
                    4  |     Type: AWS::S3::Bucket
                    5  |     Properties:
                    6  |       BucketName: !Join
                    7  |         - ''
                    8  |         - - 'sensitive-'
                    9  |           - !Ref 'AWS::AccountId'
                    10 |       OwnershipControls:
                    11 |         Rules:
                    12 |           - ObjectOwnership: 'BucketOwnerPreferred'
                    13 |       PublicAccessBlockConfiguration:
                    14 |         BlockPublicAcls: false
                    15 |         BlockPublicPolicy: false
                    16 |         IgnorePublicAcls: false
                    17 |         RestrictPublicBuckets: false
            ```

    4. Once again, this tool is quite chatty, but it does show you which checks failed, a link to more detail, and the snippet of your code that is not compliant. If you want to just see the failed resources and the title of the check, you can pipe the results to `grep` as follows:

        ```bash
        checkov --file /home/cloudshell-user/avoiding-data-disasters/TotallySecure.yaml \
          | grep -B1 FAILED
        ```

        !!! summary "Sample result"

            ```bash
            Check: CKV_AWS_53: "Ensure S3 bucket has block public ACLS enabled"
                    FAILED for resource: AWS::S3::Bucket.SensitiveBucket
            --
            Check: CKV_AWS_55: "Ensure S3 bucket has ignore public ACLs enabled"
                    FAILED for resource: AWS::S3::Bucket.SensitiveBucket
            --
            Check: CKV_AWS_54: "Ensure S3 bucket has block public policy enabled"
                    FAILED for resource: AWS::S3::Bucket.SensitiveBucket
            --
            Check: CKV_AWS_21: "Ensure the S3 bucket has versioning enabled"
                    FAILED for resource: AWS::S3::Bucket.SensitiveBucket
            --
            Check: CKV_AWS_18: "Ensure the S3 bucket has access logging enabled"
                    FAILED for resource: AWS::S3::Bucket.SensitiveBucket
            --
            Check: CKV_AWS_56: "Ensure S3 bucket has 'restrict_public_bucket' enabled"
                    FAILED for resource: AWS::S3::Bucket.SensitiveBucket
            ```

    5. It appears that **Checkov** discovered 6 findings with our original code. Now, let's see if there are any issues with the latest, most secure code.

        ```bash
        checkov --file /home/cloudshell-user/avoiding-data-disasters/MostSecure.yaml
        ```

        !!! summary "Sample result"

            ```bash
            <snip>

            Check: CKV_AWS_56: "Ensure S3 bucket has 'restrict_public_bucket' enabled"
                    PASSED for resource: AWS::S3::Bucket.SensitiveBucket
                    File: /MostSecure.yaml:3-24
                    Guide: https://docs.paloaltonetworks.com/content/techdocs/en_US/prisma/prisma-cloud/prisma-cloud-code-security-policy-reference/aws-policies/s3-policies/bc-aws-s3-22.html
            Check: CKV_AWS_57: "Ensure the S3 bucket does not allow WRITE permissions to everyone"
                    PASSED for resource: AWS::S3::Bucket.SensitiveBucket
                    File: /MostSecure.yaml:3-24
                    Guide: https://docs.paloaltonetworks.com/content/techdocs/en_US/prisma/prisma-cloud/prisma-cloud-code-security-policy-reference/aws-policies/s3-policies/s3-2-acl-write-permissions-everyone.html
            ```

    6. You should have **no remaining findings**! This would have saved us a lot of time if we would have used this tool first!

## Conclusion

This exercise really proved our approach was appropriate in solving many secure blunders and we also discovered a method to "shift security left" using a tool like **Checkov**. Now, you have a variety of ways to detect and correct storage issues that have previously rocked many organizations.
