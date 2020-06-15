module "kubeflow" {
  providers = {
    kubernetes = kubernetes
    k8s        = k8s
  }
  source = "./kubeflow"
  domain_name = var.domain_name
  use_cert_manager = module.istio.use_cert_manager
  certificate_name = module.istio.certificate_name
}
