provider "k8s" {}

provider "kubernetes" {}

resource "kubernetes_namespace" "auth" {
  metadata {
    name = "auth"
  }
}

locals {
  dex_crd_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/dex-crd.yaml",
    {
      namespace = kubernetes_namespace.auth.metadata.0.name,
    }
    )
  )
}

resource "k8s_manifest" "dex_crd" {
  count      = length(local.dex_crd_manifests)
  content    = local.dex_crd_manifests[count.index]
}