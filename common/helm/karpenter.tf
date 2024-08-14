resource "aws_iam_policy" "karpenter" {
  count  = local.enable.karpenter ? 1 : 0
  name   = format("%s_%s_karpenter_controller_policy",var.prefix,var.env)
  policy = <<JSON
{
    "Statement": [
        {
            "Action": [
                "ssm:GetParameter",
                "ec2:DescribeImages",
                "ec2:RunInstances",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeLaunchTemplates",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeInstanceTypeOfferings",
                "ec2:DescribeAvailabilityZones",
                "ec2:DeleteLaunchTemplate",
                "ec2:CreateTags",
                "ec2:CreateLaunchTemplate",
                "ec2:CreateFleet",
                "ec2:DescribeSpotPriceHistory",
                "pricing:GetProducts"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "Karpenter"
        },
        {
            "Action": "ec2:TerminateInstances",
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/karpenter.sh/nodepool": "*"
                }
            },
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "ConditionalEC2Termination"
        },
        {
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "${aws_iam_role.karpenter_node[0].arn}",
            "Sid": "PassNodeIAMRole"
        },
        {
            "Effect": "Allow",
            "Action": "eks:DescribeCluster",
            "Resource": "${data.terraform_remote_state.eks.outputs.cluster_arn}",
            "Sid": "EKSClusterEndpointLookup"
        }
    ],
    "Version": "2012-10-17"
}
JSON

  depends_on = [aws_iam_role.karpenter_node]
}


resource "aws_iam_policy" "karpenter_node" {
  count  = local.enable.karpenter ? 1 : 0
  name   = format("%s_%s_karpenter_node_policy",var.prefix,var.env)
  policy = <<JSON
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "ec2:*",
                "s3:*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }

    ]
}
JSON
}

resource "aws_iam_role" "karpenter_node" {
  count                 = local.enable.karpenter ? 1 : 0
  name                  = format("%s_%s_karpenter_node",var.prefix,var.env)
  assume_role_policy    = <<JSON
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
JSON
}

resource "aws_iam_role_policy_attachment" "karpenter_node_managed_policy" {
  count         = local.enable.karpenter ? length(local.karpenter.karpenter_node_managed_policy) : 0
  policy_arn    = local.karpenter.karpenter_node_managed_policy[count.index]
  role          = aws_iam_role.karpenter_node[0].name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_custom_policy" {
  count         = local.enable.karpenter ? 1 : 0
  policy_arn    = aws_iam_policy.karpenter_node[0].arn
  role          = aws_iam_role.karpenter_node[0].name

  depends_on    = [aws_iam_policy.karpenter_node]
}

resource "aws_iam_instance_profile" "karpenter_node" {
  count         = local.enable.karpenter ? 1 : 0
  name          = format("%s_%s_karpenter_node_profile",var.prefix,var.env)
  role          = aws_iam_role.karpenter_node[0].name

  depends_on    = [aws_iam_role.karpenter_node]
}