# sample-project
___

To see how s3 and DynamoDB handle terraform backend state let's create two projects.

## Before You Begin

### Create an IAM Role 
Create a role so that ```tf-svc-user``` can create the resources for the sample projects.
1. In the AWS console click "Create role" > "Custom trust policy" and paste the following json. This  
   establishes a trust relationship with the terraform service user and the role that allows the creation of the 
   resources required for the sample projects.
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
3. Enter a Role name such as ```tf-svc-role-sampleproject``` and click "Create role"
4. Locate the role you just created and click "Add permissions" > "Create inline policy" > "JSON"
   Paste the following JSON. Make sure and replace "\<YOUR AWS ACCOUNT ID>" with your 
   actual AWS account id:
   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
				"Effect": "Allow",
				"Action": [
					"ec2:AssociateRouteTable",
					"ec2:AttachInternetGateway",
					"ec2:AuthorizeSecurityGroupEgress",
					"ec2:AuthorizeSecurityGroupIngress",
					"ec2:CreateInternetGateway",
					"ec2:CreateRoute",
					"ec2:CreateRouteTable",
					"ec2:CreateSecurityGroup",
					"ec2:CreateSubnet",
					"ec2:CreateTags",
					"ec2:CreateVpc",
					"ec2:DeleteInternetGateway",
					"ec2:DeleteRouteTable",
					"ec2:DeleteSecurityGroup",
					"ec2:DeleteSubnet",
					"ec2:DeleteVpc",
					"ec2:DescribeImages",
					"ec2:DescribeInstances",
					"ec2:DescribeInstanceAttribute",
					"ec2:DescribeInstanceCreditSpecifications",
					"ec2:DescribeInstanceTypes",
					"ec2:DescribeInternetGateways",
					"ec2:DescribeNetworkInterfaces",
					"ec2:DescribeRouteTables",
					"ec2:DescribeSecurityGroups",
					"ec2:DescribeSubnets",
					"ec2:DescribeTags",
					"ec2:DescribeVolumes",
					"ec2:DescribeVpcAttribute",
					"ec2:DescribeVpcs",
					"ec2:DetachInternetGateway",
					"ec2:DisassociateRouteTable",
					"ec2:ModifySubnetAttribute",
					"ec2:ModifyVpcAttribute",
					"ec2:RevokeSecurityGroupEgress",
					"ec2:RunInstances",
					"ec2:TerminateInstances"
                ],
                "Resource": [
					"*"
                ]
           }
       ]
   }
   ```
5. Click "Next". Give the policy a name such as ```tf-svc-policy-sampleproject``` and click > "Create policy".

## sample-project-a
### Execute terraform commands
From the root of the project:
```
cd sample_project/sample-project-a
terraform init -backend-config=backend.conf
terraform plan 
terraform apply
```

## sample-project-b

From the root of the project:
```
cd sample_project/sample-project-b
terraform init -backend-config=backend.conf
terraform plan 
terraform apply
```


