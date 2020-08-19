provider "k8s" {
  source  = "banzaicloud/k8s"
  version = "0.8.2"
}

provider "kubernetes" {}

resource "kubernetes_namespace" "auth" {
  metadata {
    name = "auth"
  }
}