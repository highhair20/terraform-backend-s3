@todo - define permissions in tf-svc-policy


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
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::634157847749:user/jason"
            },
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::glolabs-terraform-state"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::634157847749:user/jason"
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::glolabs-terraform-state/*"
        }
    ]
}

Create Your Terraform Backend 

1. Clone this project
2. Execute Terraform commands
```
cd terraform-backend-s3
terraform init
terraform plan
terraform apply
```



Warning! It is highly recommended that you enable Bucket Versioning on the S3 bucket to allow for state recovery in the case of accidental deletions and human error.



Instead, use the variable “shared_credentials_file” and if you have several profiles like in my case the variable “profile”.

```
terraform init
```