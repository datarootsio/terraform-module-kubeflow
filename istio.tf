module "istio" {
  source                   = "./istio"
  istio_namespace          = var.istio_namespace
  istio_operator_namespace = var.istio_operator_namespace
}