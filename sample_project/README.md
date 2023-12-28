

Trust relationship
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::634157847749:user/tf-svc-user"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```


Policy for assumable role ```tf-svc-role-sampleproject```
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