# rackspace-k8s-webapi Assignment

## Deliverable

- Solution: 
	- A python flask based web application to be deployed in EKS cluster.
	- All AWS infrastructure to be created through IaC.
	
- To follow requirements:
	- Core Requirements.
	- Infrastructure Requirements.
	- Application Requirements.


## Assumptions

- There is a local linux /mac system where all below commands will be executed.
- kubectl binary (version 1.21) is installed on the system.
- Helm binary (version >=v3.9.0) is installed on the system.


## Declarations

- For this assignment, us-east-1 region is used for AWS resources.


## Step by Step Process

The entire AWS Infrastructure will be created using Terraform

### 1. Backend Support Infra:

First we need to create S3 bucket & DynamoDB table to store the Terraform state file. This S3 bucket will be private & encrypted. State for these 2 components will remain local.

- Pull this github repository - **rackspace-k8s-webapi**

- Export the AWS Access /Secret keypair as environment variable for the user (amit.naudiyal)

```
export AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXYF
export AWS_SECRET_ACCESS_KEY=p7gXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

- Install the Backend Infra:

```
cd rackspace-k8s-webapi/backend-support
terraform init
terraform plan
terraform apply
```


### 2. Base Infra:

Once S3 bucket & DDB tables are available, the rest of the AWS Infrastructure will be provisioned keeping the state file on S3 bucket and lock file on DDB table.

- Make following changes:

a. Local variable _cluster_endpoint_access_ips_ to be set as Public IP of the above local system.

- Install the Base Infra:

```
cd rackspace-k8s-webapi/base
terraform init
terraform plan
terraform apply
```

- Above will install:
	
a. A new VPC and few private /public subnets, VPC endpoints. <br>
b. EKS cluster with 1 dedicated NodeGroup. <br>
c. ECR repo. <br>
d. SSM Parameter.


- Check EKS connectivity with the local system:

```
aws eks update-kubeconfig --region us-east-1 --name interview-test-cluster
kubectl get pods -A

```


### 3. Build Application

Here we build the docker image of the Pyhton flask application and push it to ECR repo created earlier:

```
cd rackspace-k8s-webapi/app
docker build -t testapp .
docker tag testapp:latest 608157257865.dkr.ecr.us-east-1.amazonaws.com/testapp:latest
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 608157257865.dkr.ecr.us-east-1.amazonaws.com
docker push 608157257865.dkr.ecr.us-east-1.amazonaws.com/testapp:latest

```
	

### 4. Deploy Application:

The python application will be deployed via Helm chart:

```
cd rackspace-k8s-webapi/k8s
helm install k8s-webapi ./k8s-webapi
```

Following Annotations are required for IRSA to work with each Pod:

```
kubectl annotate serviceaccount -n interview-namespace default eks.amazonaws.com/role-arn=arn:aws:iam::608157257865:role/eks_pod_iam_role

kubectl annotate serviceaccount -n kube-system cluster-autoscaler eks.amazonaws.com/role-arn=arn:aws:iam::608157257865:role/cluster-autoscaler
```

- Above will create:

a. Namespace: interview-namespace. <br>
b. 3 replicas of the python application under Deployment controller. <br>
c. Loadbalancer type service. <br>
d. Cluster autoscaler.


### 5. Resultant URL:

The deployed application is available at http://ab475014e738240ab8fd77f7e4f1acea-1857788233.us-east-1.elb.amazonaws.com/




## Facts & Followed Practices:

- The EKS cluster endpoint is public, however, being allowed only on restricted IP.
- The NodeGroup is spread across 3 AZs for high availability reasons behind Autoscaling Group.
- Atleast 2 Nodes (in different AZ) will always be running to keep the traffic in more than 1 AZ behind a loadbalancer.
- Nodes are in private subnet with no access to internet at all. Access to required AWS resources is being given via multiple vpc endpoints.
- All application resources : deployment, pods, services etc are deployed in __interview-namespace__ namespace.
- IRSA (IAM Roles for ServiceAccounts) is utilized for least privilege on Pods, so they have only minimum permissions for their usage. This is for both: application pods & cluster autoscaler pods.
- The SSH keypair to login to the Node instances can be found in _loginpvtkey.pem_ file generated under rackspace-k8s-webapi/base. _(not committed)_