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

    5. To generate this bucket, we must first create a new file with this YAML content. Use the following heredoc to write the YAML content to `/home/cloudshell-user/avoiding-data-disasters/MostSecure.yaml`.

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
        EOF
        ```

### Challenge 3: Assess New Template With checkov

??? cmd "Solution"

## Conclusion
