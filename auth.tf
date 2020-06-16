module "auth" {
  providers = {
    kubernetes = kubernetes
    k8s        = k8s
  }
  source          = "./auth"
  istio_namespace = var.istio_namespace
  auth_depends_on = module.istio.wait_for_crds
}
