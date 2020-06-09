module "istio" {
  providers = {
    kubernetes = kubernetes
    k8s        = k8s
    helm       = helm
  }
  source                   = "./istio"
  istio_namespace          = var.istio_namespace
  istio_operator_namespace = var.istio_operator_namespace
}