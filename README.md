# Terraform Scaffold (terraform-scaffold)

Simple Terraform scaffold for the base of your projects.

- [Overview](#overview)
- [Usage](#usage)
- [Bootstrap](#bootstrap)
- [Plan](#plan)
- [Structure](#structure)
- [Apply](#apply)
- [Destroy](#destroy)

<a name="overview"></a>
### Overview

Un-opinionated lightweight scaffolding of a basic terraform repo. Deliberately lightweight (& for the time being un-finished).


<a name="usage"></a>
### Usage

<a name="bootstrap"></a>
##### Bootstrap

You can get setup using an s3 bucket as backend for terraform simply with the following. Be sure to check the variables.tf defaults and override them if you like.



```
cd terraform/bootstrap
terraform init
terraform plan -out tfplan.out
terraform apply "tfplan.out"
```

### NOTE

The s3 bucket for state locking must be specified in the s3_bucket of the tfscaffold.sh file before running the plan command 

<a name="plan"></a>
##### Plan

dev plan >
```

cd bin/
./tfscaffold.sh plan dev eu-west-1
```

prod plan >
```
cd bin/
./tfscaffold.sh plan prod eu-west-1
```

<a name="structure"></a>
### Structure

```
|____README.md
|____bin
| |____tfscaffold.sh (*performs orchestration of runs)
|____.gitignore
|____terraform
| |____environments
| | |____dev (*environment code - perhaps main.tf etc)
| | | |____modules
| | | | |____eks
| | | | | |____eks-cluster.tf
| | | | | |____eks-worker-nodes.tf
| | | | | |____input.tf
| | | | | |____output.tf
| | | | | |____providers.tf
| | | | | |____vpc.tf
| | | |____backend.tf
| | | |____README.md
| | | |____outputs.tf
| | | |____main.tf
| | | |____variables.tf
| | |____prod
| | | |____modules
| | | | |____eks
| | | | | |____eks-cluster.tf
| | | | | |____eks-worker-nodes.tf
| | | | | |____input.tf
| | | | | |____output.tf
| | | | | |____providers.tf
| | | | | |____vpc.tf
| | | |____README.md
| | | |____outputs.tf
| | | |____main.tf
| | | |____variables.tf
| |____templates (*dir for all templates)
| |____modules (*modules would be developed)
| | |____example
| | | |____README.md
| | | |____main.tf
| |____bootstrap (*bootstrap tf files, setup environment etc)
| | |____.terraform-version
| | |____s3_state_bucket.tf
| | |____provider_aws.tf
| | |____variables.tf
| |____components (*shared components - default variables, backend config etc) etc
| | |____backend.tf
```
<a name="apply"></a>
##### Apply

dev apply >
```

cd bin/
./tfscaffold.sh apply dev us-east-1
```

prod apply >
```
cd bin/
./tfscaffold.sh apply prod us-east-1
```

<a name="destroy"></a>
##### Destroy

dev destroy >
```

cd bin/
./tfscaffold.sh 'apply -destroy' dev us-east-1
```

prod destroy >
```
cd bin/
./tfscaffold.sh destroy prod us-east-1
```
