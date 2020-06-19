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

locals {
  kubeflow_ingress_vs_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/kubeflow/gateway-vs.yaml",
    {
      credential_name  = var.certificate_name,
      domain_name      = var.domain_name,
      istio_namespace  = var.istio_namespace
      namespace        = kubernetes_namespace.kubeflow.metadata.0.name
      use_cert_manager = var.use_cert_manager
    }
    )
  )
}

resource "k8s_manifest" "centraldashboard_application_vs" {
  depends_on = [kubernetes_deployment.kubeflow_operator]
  count      = length(local.kubeflow_ingress_vs_manifests)
  content    = local.kubeflow_ingress_vs_manifests[count.index]
}


