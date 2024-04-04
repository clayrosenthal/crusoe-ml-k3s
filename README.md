# Rancher K3s Deployment on Crusoe Cloud

## Known Issues

If the Terraform below fails contact support@crusoecloud.com for help.

## Requirements

- [Terraform CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- [Crusoe Cloud Cli](https://docs.crusoecloud.com/quickstart/installing-the-cli/index.html)
- [Crusoe Cloud Credentials](https://docs.crusoecloud.com/account-management/managing-api-keys)
  - Either stored in `~/.crusoe/credentials` or exported as environment variables `CRUSOE_x`
- []

## Deployment

To use as a module fill in the `variables` in a `main.tf` file

```
module "crusoe" {
  source = "github.com/crusoecloud/crusoe-ml-k3s"
  ssh_privkey_path="</path/to/priv.key"
  ssh_pubkey="<pub_key>"
  worker_instance_type = "h100-80gb-sxm-ib.8x"
  worker_image = "ubuntu22.04-nvidia-sxm-docker:latest"
  worker_count = 2
  ib_partition_id = "6dcef748-dc30-49d8-9a0b-6ac87a27b4f8"
  headnode_instance_type="c1a.8x"
  deploy_location = "us-east1-a"
  # extra variables here
}
```

To use from this directory, fill in the `variables` in a `terraform.tfvars` file

```
ssh_privkey_path="</path/to/priv.key"
ssh_pubkey="<pub_key>"
worker_instance_type = "h100-80gb-sxm-ib.8x"
worker_image = "ubuntu22.04-nvidia-sxm-docker:latest"
worker_count = 2
ib_partition_id = "6dcef748-dc30-49d8-9a0b-6ac87a27b4f8"
headnode_instance_type="c1a.8x"
deploy_location = "us-east1-a"
# extra variables here
```

And then apply, to provision resources

```
terraform init
terraform plan
terraform apply
```

## Accessing the Cluster

Once the deployment is complete, you can access the cluster by copying the `kubeconfig` file from the headnode

```bash
k3s_endpoint=$(terraform output -raw k3-ingress-instance_public_ip)
headnode_endpoint=$(terraform output -raw k3-headnode-instance_public_ip)
scp -i $TF_VAR_ssh_privkey_path "root@${headnode_endpoint}:/etc/rancher/k3s/k3s.yaml" ./kubeconfig
# change the endpoint to the kubectl endpoint
sed -i '' "s/127.0.0.1/${k3s_endpoint}/g" ./kubeconfig
# rename the context (optional)
sed -i '' "s/default/crusoe/g" ./kubeconfig
export KUBECONFIG="$(pwd)/kubeconfig"
```

## Nvidia GPU Support

To ensure the nvidia GPUs are available in the cluster, you can run the following commands

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
helm install --wait --generate-name -n gpu-operator --create-namespace nvidia/gpu-operator --set driver.rdma.enabled=true --set driver.rdma.useHostMofed=true
helm install network-operator nvidia/network-operator -n nvidia-network-operator --create-namespace -f ./gpu-operator/values.yaml --wait
```

To test the GPU infiniband speeds, you can run the following command

```bash
kubectl apply -f https://raw.githubusercontent.com/kubeflow/mpi-operator/v0.4.0/deploy/v2beta1/mpi-operator.yaml
kubectl apply -f examples/nccl-test.yaml
```
