resource "kubernetes_namespace" "auth" {
  metadata {
    name = "auth"
  }
}