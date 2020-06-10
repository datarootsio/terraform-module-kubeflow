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

locals {
  kiali = split(
    "\n---\n", templatefile("${path.module}/manifests/kiali.yaml",
      {
        credential_name  = var.certificate_name,
        domain_name      = var.domain_name,
        lb_ip            = var.ingress_gateway_ip,
        namespace        = var.istio_namespace,
        use_cert_manager = var.use_cert_manager
      }
    )
  )
}

resource "k8s_manifest" "cert_manager_crds" {
  depends_on = [kubernetes_deployment.istio_operator, kubernetes_cluster_role_binding.istio_operator]
  count      = length(local.kiali)
  content    = local.kiali[count.index]
}