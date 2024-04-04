variable "ssh_pubkey" {
  description = "The ssh public key to use for the instances"
}

variable "ssh_privkey_path" {
  description = "The path to the ssh private key to auth to the instances"
}

variable "headnode_image" {
  description = "The image to use for creating the headnode instance"
  default     = "ubuntu22.04:latest"
}

variable "headnode_instance_type" {
  description = "Name of the instance type to use for the headnode instance"
  default     = "c1a.8x"
}

variable "headnode_count" {
  description = "How many headnodes to use, 1 implies no loadbalancing"
  default     = 3
}
variable "worker_image" {
  description = "The image to use for creating the worker instances"
  default     = "ubuntu22.04-nvidia-sxm-docker:latest"
}

variable "worker_instance_type" {
  description = "Name of the instance type to use for the worker instances"
  default     = "h100-80gb-sxm-ib.8x"
}

variable "worker_count" {
  description = "Number of worker instances to create"
  default     = 2
}

variable "ib_partition_id" {
  description = "infiniband partition id to use for the cluster"
}

variable "deploy_location" {
  description = "region to deploy the cluster in"
  default     = "us-east1-a"
}

variable "instance_name_prefix" {
  description = "Prefix to use for the instance names"
  default     = "crusoe"
}
