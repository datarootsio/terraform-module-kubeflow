resource "kubernetes_namespace" "cert_manager" {
  metadata {
    annotations = {
      name = var.cert_manager_namespace
    }
    name = var.cert_manager_namespace
  }
}

locals {
  cert_manager_crds = split("\n---\n", templatefile("${path.module}/manifests/cert-manager/${var.cert_manager_version}/crds.yaml", {}))
}

resource "k8s_manifest" "cert_manager_crds" {
  count   = length(local.cert_manager_crds)
  content = local.cert_manager_crds[count.index]
}

resource "helm_release" "cert_manager" {
  depends_on    = [k8s_manifest.cert_manager_crds]
  name          = "cert-manager"
  chart         = "cert-manager"
  keyring       = ""
  namespace     = kubernetes_namespace.cert_manager.metadata.0.name
  recreate_pods = true
  repository    = "https://charts.jetstack.io"
  version       = var.cert_manager_version
}
