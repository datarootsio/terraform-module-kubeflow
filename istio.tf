module "istio" {
  providers = {
    kubernetes = kubernetes
    k8s        = k8s
    helm       = helm
  }
  source                      = "./istio"
  domain_name                 = var.domain_name
  ingress_gateway_annotations = var.ingress_gateway_annotations
  ingress_gateway_ip          = var.ingress_gateway_ip
  istio_namespace             = var.istio_namespace
  istio_operator_namespace    = var.istio_operator_namespace
  use_cert_manager            = var.use_cert_manager
  certificate_name            = var.certificate_name
  istio_depends_on            = helm_release.cert_manager
}