resource "aws_iam_role" "eks_cluster" {
  name                  = format("%s_%s_eks_cluster",var.prefix,var.env)
  assume_role_policy    = <<JSON
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "eks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
JSON
}

resource "aws_iam_policy" "eks_node" {
  name   = format("%s_%s_eks_node_policy",var.prefix,var.env)
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

resource "aws_iam_role" "eks_node" {
  name                  = format("%s_%s_eks_node",var.prefix,var.env)
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

resource "aws_iam_role_policy_attachment" "eks_cluster_managed_policy" {
  count         = length(local.iam_node_managed_policy.eks_cluster_managed_policy) 
  policy_arn    = local.iam_node_managed_policy.eks_cluster_managed_policy[count.index]
  role          = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_node_managed_policy" {
  count         = length(local.iam_node_managed_policy.eks_node_managed_policy) 
  policy_arn    = local.iam_node_managed_policy.eks_node_managed_policy[count.index]
  role          = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_node_custom_policy" {
  policy_arn    = aws_iam_policy.eks_node.arn
  role          = aws_iam_role.eks_node.name

  depends_on    = [aws_iam_policy.eks_node]
}
