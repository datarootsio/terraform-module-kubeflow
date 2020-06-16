module "auth" {
  providers = {
    kubernetes = kubernetes
    k8s        = k8s
  }
  source          = "./auth"
  istio_namespace = var.istio_namespace
}
