provider "k8s" {}

provider "kubernetes" {}

resource "kubernetes_namespace" "auth" {
  metadata {
    name = "auth"
  }
}