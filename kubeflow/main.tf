provider "k8s" {}

provider "kubernetes" {}

resource "kubernetes_namespace" "kubeflow" {
  metadata {
    name = "kubeflow"
  }
}

locals {
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "kubeflow"
  }
}

locals {
  kubeflow_gateway = split(
    "\n---\n", templatefile("${path.module}/manifests/kubeflow-gateway.yaml",
      {
        credential_name  = var.certificate_name,
        domain_name      = var.domain_name,
        namespace        = kubernetes_namespace.kubeflow.metadata.0.name
        use_cert_manager = var.use_cert_manager
      }
    )
  )
}

resource "k8s_manifest" "kubeflow_gateway" {
  depends_on = [kubernetes_namespace.kubeflow]
  count      = length(local.kubeflow_gateway)
  content    = local.kubeflow_gateway[count.index]
}
