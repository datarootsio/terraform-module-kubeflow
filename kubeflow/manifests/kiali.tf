locals {
  kiali = split(
    "\n---\n", templatefile("${path.module}/manifests/kiali.yaml",
      {
        credential_name  = var.certificate_name,
        domain_name      = var.domain_name,
        namespace        = kubernetes_namespace.kubeflow.metadata.0.name
        use_cert_manager = var.use_cert_manager
      }
    )
  )
}

resource "k8s_manifest" "kiali_manifests" {
  depends_on = [var.istio_depends_on, k8s_manifest.operator_crd, kubernetes_deployment.istio_operator, kubernetes_cluster_role_binding.istio_operator, null_resource.wait_crds]
  count      = length(local.kiali)
  content    = local.kiali[count.index]
}