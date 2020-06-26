provider "kubernetes" {}

provider "k8s" {
  source = "registry.terraform.local/banzaicloud/k8s"
  version = "0.7.7"
}

provider "helm" {}

module "auth" {
  providers = {
    kubernetes = kubernetes
    k8s        = k8s
  }
  source             = "./auth"
  application_secret = var.oidc_client_secret
  auth_depends_on    = [module.istio.wait_for_crds, k8s_manifest.kubeflow_application_crd]
  client_id          = var.oidc_client_id
  domain_name        = var.domain_name
  issuer             = var.oidc_issuer
  istio_namespace    = var.istio_namespace
  oidc_auth_url      = var.oidc_auth_url
  oidc_redirect_url  = var.oidc_redirect_url
  userid_claim       = var.oidc_userid_claim
}

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
  ingress_gateway_selector    = var.ingress_gateway_selector
  istio_namespace             = var.istio_namespace
  istio_operator_namespace    = var.istio_operator_namespace
  use_cert_manager            = var.use_cert_manager
  certificate_name            = var.certificate_name
  istio_depends_on            = helm_release.cert_manager
}
