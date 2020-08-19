variable "install_istio" {
  type    = bool
  default = false
}

variable "istio_namespace" {
  type    = string
  default = "istio-system"
}

variable "istio_operator_namespace" {
  type    = string
  default = "istio-operator"
}

variable "cert_manager_namespace" {
  type    = string
  default = "cert-manager"
}

variable "kubeflow_operator_namespace" {
  type    = string
  default = "kubeflow-operator"
}

variable "cert_manager_version" {
  type    = string
  default = "v0.15.1"
}

variable "ingress_gateway_annotations" {
  type    = map(string)
  default = {}
}

variable "ingress_gateway_ip" {
  type    = string
  default = ""
}

variable "ingress_gateway_selector" {
  type    = string
  default = "ingressgateway"
}

variable "dns_record" {
  type    = string
  default = "kubeflow"
}

variable "domain_name" {
  type    = string
  default = ""
}

variable "use_cert_manager" {
  type    = bool
  default = false
}

variable "certificate_name" {
  type    = string
  default = ""
}

variable "letsencrypt_email" {
  type    = string
  default = ""
}

variable "oidc_client_secret" {
  type    = string
  default = "pUBnBOY80SnXgjibTYM9ZWNzY2xreNGQok"
}

variable "oidc_userid_claim" {
  type    = string
  default = "email"
}

variable "oidc_auth_url" {
  type    = string
  default = "/dex/auth"
}

variable "oidc_client_id" {
  type    = string
  default = "kubeflow-oidc-authservice"
}

variable "oidc_issuer" {
  type    = string
  default = "http://dex.auth.svc.cluster.local:5556/dex"
}

variable "oidc_redirect_url" {
  type    = string
  default = "/login/oidc"
}

variable "kubeflow_components" {
  type    = list(string)
  default = ["jupyter", "spark", "pytorch", "knative", "spartakus", "tensorflow", "katib", "pipelines", "seldon"]
}

variable "kubeflow_version" {
  type = string
  default = "1.0.2"
}