provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks_blueprints.eks_cluster_id
}

data "aws_availability_zones" "available" {}

locals {
  name   = basename(path.cwd)
  region = "us-west-2"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
}

#---------------------------------------------------------------
# EKS Blueprints
#---------------------------------------------------------------
module "eks_blueprints" {
  source = "../../.."

  cluster_name    = local.name
  cluster_version = "1.23"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  self_managed_node_groups = {
    self_mg4 = {
      node_group_name    = "self_mg4"
      launch_template_os = "amazonlinux2eks"
      subnet_ids         = module.vpc.private_subnets
    }
    self_mg5 = {
      node_group_name = "self_mg5" # Name is used to create a dedicated IAM role for each node group and adds to AWS-AUTH config map

      subnet_type            = "private"
      subnet_ids             = module.vpc.private_subnets # Optional defaults to Private Subnet Ids used by EKS Control Plane
      create_launch_template = true
      launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or bottlerocket or windows
      custom_ami_id          = ""                # Bring your own custom AMI generated by Packer/ImageBuilder/Puppet etc.

      create_iam_role           = false                                         # Changing `create_iam_role=false` to bring your own IAM Role
      iam_role_arn              = aws_iam_role.self_managed_ng.arn              # custom IAM role for aws-auth mapping; used when create_iam_role = false
      iam_instance_profile_name = aws_iam_instance_profile.self_managed_ng.name # IAM instance profile name for Launch templates; used when create_iam_role = false

      format_mount_nvme_disk = true
      public_ip              = false
      enable_monitoring      = false

      enable_metadata_options = false

      pre_userdata = <<-EOT
        yum install -y amazon-ssm-agent
        systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
      EOT

      post_userdata = <<-EOT
      	sudo yum update
      	sudo yum install java-1.8.0-openjdk
      	java -version
      	sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat/jenkins.repo
      	sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
      	sudo yum install jenkins
      	sudo service jenkins start
      EOT 
        # Optional config

      # --node-labels is used to apply Kubernetes Labels to Nodes
      # --register-with-taints used to apply taints to Nodes
      # e.g., kubelet_extra_args='--node-labels=WorkerType=SPOT,noderole=spark --register-with-taints=spot=true:NoSchedule --max-pods=58',
      kubelet_extra_args = "--node-labels=WorkerType=SPOT,noderole=spark --register-with-taints=test=true:NoSchedule --max-pods=20"

      # bootstrap_extra_args used only when you pass custom_ami_id. Allows you to change the Container Runtime for Nodes
      # e.g., bootstrap_extra_args="--use-max-pods false --container-runtime containerd"
      bootstrap_extra_args = "--use-max-pods false"

      block_device_mappings = [
        {
          device_name = "/dev/xvda" # mount point to /
          volume_type = "gp3"
          volume_size = 50
        },
        {
          device_name = "/dev/xvdf" # mount point to /local1 (it could be local2, depending upon the disks are attached during boot)
          volume_type = "gp3"
          volume_size = 80
          iops        = 3000
          throughput  = 125
        },
        {
          device_name = "/dev/xvdg" # mount point to /local2 (it could be local1, depending upon the disks are attached during boot)
          volume_type = "gp3"
          volume_size = 100
          iops        = 3000
          throughput  = 125
        }
      ]

      instance_type = "m5.large"
      desired_size  = 2
      max_size      = 10
      min_size      = 2
      capacity_type = "" # Optional Use this only for SPOT capacity as  capacity_type = "spot"

      k8s_labels = {
        Environment = "preprod"
        Zone        = "test"
        WorkerType  = "SELF_MANAGED_ON_DEMAND"
      }

      additional_tags = {
        ExtraTag    = "m5x-on-demand"
        Name        = "m5x-on-demand"
        subnet_type = "private"
      }
    }

    spot_2vcpu_8mem = {
      node_group_name    = "smng-spot-2vcpu-8mem"
      capacity_type      = "spot"
      capacity_rebalance = true
      instance_types     = ["m5.large", "m4.large", "m6a.large", "m5a.large", "m5d.large"]
      min_size           = 0
      subnet_ids         = module.vpc.private_subnets
      launch_template_os = "amazonlinux2eks" # amazonlinux2eks or bottlerocket
      k8s_taints         = [{ key = "spotInstance", value = "true", effect = "NO_SCHEDULE" }]
    }

    spot_4vcpu_16mem = {
      node_group_name    = "smng-spot-4vcpu-16mem"
      capacity_type      = "spot"
      capacity_rebalance = true
      instance_types     = ["m5.xlarge", "m4.xlarge", "m6a.xlarge", "m5a.xlarge", "m5d.xlarge"]
      min_size           = 0
      subnet_ids         = module.vpc.private_subnets
      launch_template_os = "amazonlinux2eks" # amazonlinux2eks or bottlerocket
      k8s_taints         = [{ key = "spotInstance", value = "true", effect = "NO_SCHEDULE" }]
    }
  }
}

module "eks_blueprints_kubernetes_addons" {
  source                   = "../../../modules/kubernetes-addons"
  eks_cluster_id           = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint     = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider        = module.eks_blueprints.oidc_provider
  eks_cluster_version      = module.eks_blueprints.eks_cluster_version
  auto_scaling_group_names = module.eks_blueprints.self_managed_node_group_autoscaling_groups

  # EKS Managed Add-ons
  enable_amazon_eks_vpc_cni    = true
  enable_amazon_eks_coredns    = true
  enable_amazon_eks_kube_proxy = true

  #K8s Add-ons
  enable_metrics_server               = true
  enable_aws_node_termination_handler = true

  enable_cluster_autoscaler = true
  cluster_autoscaler_helm_config = {
    set = [
      {
        name  = "extraArgs.expander"
        value = "priority"
      },
      {
        name  = "expanderPriorities"
        value = <<-EOT
                  100:
                    - .*-spot-2vcpu-8mem.*
                  90:
                    - .*-spot-4vcpu-16mem.*
                  10:
                    - .*
                EOT
      }
    ]
  }
}

#---------------------------------------------------------------
# Custom IAM role for Self Managed Node Group
#---------------------------------------------------------------
data "aws_iam_policy_document" "self_managed_ng_assume_role_policy" {
  statement {
    sid = "EKSWorkerAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "self_managed_ng" {
  name                  = "self-managed-node-role"
  description           = "EKS Managed Node group IAM Role"
  assume_role_policy    = data.aws_iam_policy_document.self_managed_ng_assume_role_policy.json
  path                  = "/"
  force_detach_policies = true
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  tags = local.tags
}

resource "aws_iam_instance_profile" "self_managed_ng" {
  name = "self-managed-node-instance-profile"
  role = aws_iam_role.self_managed_ng.name
  path = "/"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

#---------------------------------------------------------------
# Supporting Resources
#---------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
  }

  tags = local.tags
}
