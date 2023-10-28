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

3. ___Lease Mechanism___: DynamoDB is used to implement a lease mechanism for the state lock. When a user or process acquires the lock, it's essentially leasing the lock for a specific duration. If the user or process crashes or fails to release the lock due to some issue, the lease ensures that the lock eventually becomes available for other users or processes.


## Before You Begin
### Create an IAM User 
1. It is best practice to create a Terraform service user with minimum permissions specific to the given project. 
For this project I created an IAM user called ```tf-svc-user-state```.
2. Add the following policy to your newly created user:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Statement1",
            "Effect": "Allow",
            "Action": [
                "dynamodb:CreateTable",
                "dynamodb:DeleteTable",
                "dynamodb:DescribeTable",
                "dynamodb:DescribeContinuousBackups",
                "dynamodb:DescribeTimeToLive",
                "dynamodb:ListTagsOfResource",
                "dynamodb:TagResource",
                "kms:CreateKey",
                "kms:DescribeKey",
                "kms:GetKeyPolicy",
                "kms:GetKeyRotationStatus",
                "kms:ListResourceTags",
                "kms:ListResourceTags",
                "kms:ScheduleKeyDeletion",
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
            "Resource": "*"
        }
    ]
}
```
3. For the newly created user under 'Security Credentials', create an 'Access key'. 
Add the ```aws_access_key_id``` and ```aws_secret_access_key``` to your ```~/.aws/credentials``` file.

### Have the following info handy
You will be prompted when running terraform.
Alternatively you can can create a ```terraform.tfvars``` file with these values in it. I don't recommend checking it into git.
   * aws_account_id = "\<YOUR AWS ACCOUNT ID>"
   * aws_profile = "tf-svc-user-state"
   * aws_region = "us-east-1"
   * bucket_name = "\<YOUR PROJECT>-terraform-backend" 
   

## Create Your Terraform Backend
2. Clone this project
3. Execute Terraform commands
```
cd terraform-backend-s3
terraform init
terraform plan
terraform apply
```

