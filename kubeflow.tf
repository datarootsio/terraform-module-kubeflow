module "kubeflow" {
  providers = {
    kubernetes = kubernetes
    k8s        = k8s
  }
  source              = "./kubeflow"
  domain_name         = var.domain_name
  use_cert_manager    = var.use_cert_manager
  certificate_name    = var.certificate_name
  istio_namespace     = var.istio_namespace
  kubeflow_depends_on = module.istio.wait_for_crds
}
