variable "istio_namespace" {
  type    = string
  default = "istio-system"
}

variable "istio_operator_namespace" {
  type    = string
  default = "istio-operator"
}

variable "ingress_gateway_annotations" {
  type = map(string)
  default = {}
}

variable "ingress_gateway_ip" {
  type = string
  default = ""
}