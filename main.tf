provider "kubernetes" {}

provider "k8s" {}

provider "helm" {}

terraform {
  required_version = "~> 0.12"
}

module "auth" {
  providers = {
    kubernetes = kubernetes
    k8s        = k8s
  }
  source             = "./auth"
  application_secret = var.oidc_client_secret
  auth_depends_on    = module.istio.wait_for_crds
  client_id          = var.oidc_client_id
  domain_name        = var.domain_name
  issuer             = var.oidc_issuer
  istio_namespace    = var.istio_namespace
  oidc_auth_url      = var.oidc_auth_url
  oidc_redirect_url  = var.oidc_redirect_url
  userid_claim       = var.oidc_userid_claim
}

/*
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
  kubeflow_depends_on = [module.istio.wait_for_crds, helm_release.cert_manager]
}

module "knative" {
  providers = {
    kubernetes = kubernetes
    k8s        = k8s
  }
  source             = "./knative"
  knative_depends_on = [module.istio.wait_for_crds, helm_release.cert_manager]
}*/

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
