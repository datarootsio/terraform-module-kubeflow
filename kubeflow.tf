resource "kubernetes_namespace" "kubeflow" {
  depends_on = [module.istio.wait_for_crds, helm_release.cert_manager]
  metadata {
    name = "kubeflow"
  }
}

resource "k8s_manifest" "kubeflow_kfdef" {
  content = templatefile("${path.module}/manifests/kubeflow/kfdef.yaml",
    { namespace = kubernetes_namespace.kubeflow.metadata.0.name }
  )
}