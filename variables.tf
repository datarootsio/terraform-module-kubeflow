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