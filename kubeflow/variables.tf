variable "domain_name" {
  type = string
}

variable "use_cert_manager" {
  type    = bool
  default = false
}

variable "certificate_name" {
  type = string
  default = ""
}

variable "istio_namespace" {
  type = string
}

variable "kubeflow_depends_on" {
  type    = any
  default = null
}