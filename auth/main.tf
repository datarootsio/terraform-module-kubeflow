terraform {
  required_version = "~> 1.0.0"
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    k8s = {
      source  = "banzaicloud/k8s"
      version = "0.8.2"
    }
  }
}

resource "kubernetes_namespace" "auth" {
  metadata {
    name = "auth"
  }
}