provider "k8s" {}

provider "kubernetes" {}

resource "kubernetes_namespace" "kubeflow" {
  metadata {
    name = "kubeflow"
  }
}

locals {
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "kubeflow"
  }
}