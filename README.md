# terraform-backend-s3
___

## Overview
The purpose of this project is to create the AWS cloud resources required for a Terraform s3 backend. If you plan 
on using Terraform in any of your projects, you may be interested in running this first.

In Terraform, a backend determines how the state is stored and accessed, and it plays a crucial role in managing 
the state of your infrastructure. The state file contains metadata about your infrastructure and configuration, 
which Terraform uses to understand the current state of your resources and to plan and apply changes.

The S3 backend is one of the remote backends provided by Terraform, and it's commonly used to store the state file 
in a centralized Amazon S3 bucket. Here's why the S3 backend is valuable and how it works:

1. ___Centralized State Storage___: By using the S3 backend, you can store your Terraform state in a centralized S3 bucket. 
This is particularly beneficial for teams working on the same infrastructure because it provides a single source of 
truth for the state data. Each team member can access the same state, ensuring consistency and collaboration.
2. ___Versioning___: S3 buckets can be configured to enable versioning. This means that each state file update is stored as a 
new version, allowing you to track changes over time. In case of errors or issues, you can easily revert to a previous 
state version to recover from problems.

3. ___Concurrency___: The S3 backend allows multiple team members to work on the same infrastructure simultaneously. 
Terraform uses locking mechanisms to prevent conflicts when multiple users attempt to apply changes concurrently.

4. ___Security___: S3 provides robust access control and encryption features, ensuring the security and privacy of your 
state data. You can restrict access to the S3 bucket to authorized users and applications.

Additionally, we will be using a DynamoDB for locking and consistency management when multiple users or processes are 
working with the same Terraform state stored in an S3 bucket. State locking is crucial to prevent concurrent 
modifications that could lead to inconsistencies in the state file. Here's how DynamoDB is used in this context:

1. ___Locking Mechanism___: When Terraform initializes and interacts with the S3 backend, it first attempts to acquire 
a lock on the state file using DynamoDB. This lock ensures that only one user or process can make changes to the state 
at a given time. If another user or process attempts to access the state while it's locked, it will wait until 
the lock is released.

2. ___State Consistency___: DynamoDB helps ensure that the state file remains consistent, even in scenarios with 
multiple Terraform users or concurrent operations. It prevents race conditions and potential corruption 
of the state file.

3. ___Lease Mechanism___: DynamoDB is used to implement a lease mechanism for the state lock. When a user or process 
acquires the lock, it's essentially leasing the lock for a specific duration. If the user or process crashes or fails 
to release the lock due to some issue, the lease ensures that the lock eventually becomes available for other users 
or processes.

The s3 and DynamoDB resources created in this project can hold the state of an unlimited number of projects.

## Before You Begin
In the AWS Console... 
### Create an IAM User 
It is best practice to create a Terraform service user with minimum permissions specific to the given project. 
I created an IAM user called ```tf-svc-user``` whose default permissions will only allow it to create and manage
a remote backend for other projects. Any project specific permissions will be independently defined and then assumed 
by the ```tf-svc-user``` as part of that project.  
1. In the AWS console go to "IAM" > "Users" > "Create user"
2. Enter a username named ```tf-svc-user``` and click "Next" > "Next" > "Create user"
3. Click on the newly created user and go to "Add permissions" > "Create inline policy" > "JSON".
4. Paste the following permissions:
    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:ListBucket"
                ],
                "Resource": "arn:aws:s3:::<UNIQUE PREFIX>-terraform-backend"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:DeleteObject"
                ],
                "Resource": "arn:aws:s3:::<UNIQUE PREFIX>-terraform-backend/*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "dynamodb:DescribeTable",
                    "dynamodb:GetItem",
                    "dynamodb:PutItem",
                    "dynamodb:DeleteItem"
                ],
                "Resource": "arn:aws:dynamodb:*:*:table/terraform_state"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "kms:Decrypt",
                    "kms:GenerateDataKey"
                ],
                "Resource": [
                    "arn:aws:kms:*:*:key/*"
                ]
            }
        ]
    }
    ```
5. Click "Next", provide a meaning policy name such as ```tf-svc-policy-state``` and click "Create policy" 
6. For the newly created user go to 
   "Security Credentials" > "Access keys" > "Create access key" > "Other" > "Next" > "Create access key" 
   and add the ```aws_access_key_id``` and ```aws_secret_access_key``` to your local ```~/.aws/credentials``` file.

### Create an IAM Role 
Create a role so that ```tf-svc-user``` can create the resources for the remote backend.
1. In the AWS console click "Create role" > "Custom trust policy" and paste the following json. This  
   establishes a trust relationship with the terraform service user and the role that allows the creation of the 
   resources required for the backend s3.
   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Principal": {
                   "AWS": "arn:aws:iam::<YOUR AWS ACCOUNT ID>:user/tf-svc-user",
               },
               "Action": "sts:AssumeRole"
           }
       ]
   }
   ```
2. Click "Next" > "Next"
3. Enter a Role name such as ```tf-svc-role-state``` and click "Create role"
4. Locate the role you just created and click "Add permissions" > "Create inline policy" > "JSON"
   (Why didn't AWS include this step in the "create role" flow? I don't know why. I will ask.)
   Paste the following JSON. Make sure and replace "\<YOUR AWS ACCOUNT ID>" with your 
   actual AWS account id:
   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Sid": "DynamoStatement",
               "Effect": "Allow",
               "Action": [
                   "dynamodb:CreateTable",
                   "dynamodb:DeleteTable",
                   "dynamodb:DescribeContinuousBackups",
                   "dynamodb:DescribeTable",
                   "dynamodb:DescribeTimeToLive",
                   "dynamodb:ListTagsOfResource",
                   "dynamodb:TagResource"
               ],
               "Resource": [
                   "arn:aws:dynamodb:*:<YOUR AWS ACCOUNT ID>:table/terraform_state"
               ]
           },
           {
               "Sid": "s3Statement",
               "Effect": "Allow",
               "Action": [
                   "s3:CreateBucket",
                   "s3:DeleteBucketPolicy",
                   "s3:DeleteBucket",
                   "s3:GetAccelerateConfiguration",
                   "s3:GetBucketAcl",
                   "s3:GetBucketCORS",
                   "s3:GetBucketLogging",
                   "s3:GetBucketObjectLockConfiguration",
                   "s3:GetBucketOwnershipControls",
                   "s3:GetBucketPolicy",
                   "s3:GetBucketRequestPayment",
                   "s3:GetBucketTagging",
                   "s3:GetBucketVersioning",
                   "s3:GetBucketWebsite",
                   "s3:GetEncryptionConfiguration",
                   "s3:GetLifecycleConfiguration",
                   "s3:GetReplicationConfiguration",
                   "s3:ListBucket",
                   "s3:PutBucketTagging",
                   "s3:PutBucketObjectLockConfiguration",
                   "s3:PutEncryptionConfiguration",
                   "s3:PutBucketOwnershipControls",
                   "s3:PutBucketAcl",
                   "s3:PutBucketVersioning"
               ],
               "Resource": [
                   "arn:aws:s3:::*-terraform-backend"
               ]
           },
           {
               "Sid": "KMSStatement",
               "Effect": "Allow",
               "Action": [
                   "kms:CreateKey",
                   "kms:DescribeKey",
                   "kms:GetKeyPolicy",
                   "kms:GetKeyRotationStatus",
                   "kms:ListResourceTags",
                   "kms:ListResourceTags",
                   "kms:ScheduleKeyDeletion"
               ],
               "Resource": [
                   "arn:aws:kms:*:<YOUR AWS ACCOUNT ID>:key/*"
               ]
           },
           {
               "Sid": "KMSStatement2",
               "Effect": "Allow",
               "Action": [
                   "kms:CreateKey"
               ],
               "Resource": [
                   "*"
               ]
           }
       ]
   }
   ```
5. Click "Next". Give the policy a name such as ```tf-svc-policy-state``` and click > "Create policy".

### Have the following info handy
You will be prompted for the following when running terraform.
Alternatively you can create a ```terraform.tfvars``` file with these values in it. I don't recommend checking it into git.
```
aws_account_id = "<YOUR AWS ACCOUNT ID>"
aws_region = "us-east-1"
s3_bucket = "<UNIQUE PREFIX>-terraform-backend"
```

## Create Your Terraform Backend
1. Clone this project
2. Execute Terraform commands
```
cd terraform-backend-s3
terraform init
terraform plan
terraform apply
```
That's it. You should now have an s3 bucket for storing backend state and a DynamoDB table for 
locking the state so no two users can change it at the same time.

## See it in action
This section is optional and is only to see how objects and state manifest themselves in s3 and DynamoDB
for actual projects. 

For a detailed walk-through of sample projects go [here](sample_project/README.md).

Once you are done your s3 bucket should looks something like:

![S3 bucket containing two sample projects](https://highhair20-github-images.s3.amazonaws.com/terraform-backend-s3/dynamodb.png)


and your DynamoDB table should look something like:

![DynamoDB table containing two sample projects](https://highhair20-github-images.s3.amazonaws.com/terraform-backend-s3/dynamodb.png)


## Good things to know
### How to start over
You may have created your state bucket and added some test projects but want to start fresh.
You might think that you can simply run ```terraform destroy``` and, boom, you're done.
However, that's not the case. 

Due to the proper configuration of managing remote state, we are keeping a history in s3 which prevents
```terraform destroy``` from completing successfully due to the s3 versions that are saved.
To get past this you have to delete the versions manually. To do so:
1. In s3 click on the bucket containing your state.
2. Click on the Object you wish to delete. 
3. Click on the "Show versions" slider near the search bar.
4. To "select all" click the checkbox near "Name".
5. Click "Delete".
6. Sroll to the bottom. Type "permanently delete" in the text box and click "Delete objects".

Follow the previous steps to delete all other objects from the bucket.