provider "k8s" {}

provider "kubernetes" {}

resource "k8s_manifest" "operator_crd" {
  depends_on = [kubernetes_cluster_role_binding.istio_operator]
  content    = templatefile("${path.module}/manifests/operator-crd.yaml", {})
}

resource "kubernetes_namespace" "istio_namespace" {
  metadata {
    name = var.istio_namespace

    labels = {
      istio-injection = "disabled"

      istio-operator-managed = "Reconcile"
    }
  }
}

resource "k8s_manifest" "istio_deployment" {
  depends_on = [kubernetes_deployment.istio_operator, kubernetes_cluster_role_binding.istio_operator]
  content = templatefile(
    "${path.module}/manifests/istio-deployment.yaml",
    {
      namespace   = kubernetes_namespace.istio_namespace.metadata.0.name,
      annotations = var.ingress_gateway_annotations,
      lb_ip       = var.ingress_gateway_ip
    }
  )
}