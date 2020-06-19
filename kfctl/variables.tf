variable "kfctl_namespace" {
  type    = string
  default = "kfctl-operator"
}

variable "kfctl_depends_on" {
  type    = any
  default = null
}