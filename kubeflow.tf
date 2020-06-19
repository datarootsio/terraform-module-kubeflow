resource "kubernetes_namespace" "kubeflow" {
  depends_on = [module.istio.wait_for_crds, helm_release.cert_manager]
  metadata {
    name = "kubeflow"
    labels = {
      "control-plane"                    = "kubeflow"
      "katib-metricscollector-injection" = "enabled"
    }
  }
}

resource "k8s_manifest" "kubeflow_application_crd" {
  content = templatefile("${path.module}/manifests/kubeflow/application-crd.yaml", {}
  )
}

resource "k8s_manifest" "kubeflow_kfdef" {
  depends_on = [kubernetes_deployment.kubeflow_operator]
  timeouts {
    delete = "60m"
  }
  content = templatefile("${path.module}/manifests/kubeflow/kfdef.yaml",
    { namespace = kubernetes_namespace.kubeflow.metadata.0.name }
  )
}