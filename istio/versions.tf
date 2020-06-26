terraform {
  required_providers {
    k8s = {
      source = "registry.terraform.local/banzaicloud/k8s"
      version = "0.7.7"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    null = {
      source = "hashicorp/null"
    }
  }
  required_version = ">= 0.13"
}
