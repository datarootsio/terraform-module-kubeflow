module "kubeflow" {
  providers = {
    kubernetes = kubernetes
    k8s        = k8s
  }
  source           = "./kubeflow"
  domain_name      = var.domain_name
  use_cert_manager = var.use_cert_manager
  certificate_name = var.certificate_name
}
