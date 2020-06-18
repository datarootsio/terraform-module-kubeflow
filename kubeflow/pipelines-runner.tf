locals {
  labels_pipelines_runner = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "pipelines-runner"
      "app.kubernetes.io/name"      = "pipelines-runner"
      "app.kubernetes.io/instance"  = "pipelines-runner-0.2.5"
      "app.kubernetes.io/version"   = "0.2.5"
    }
  )
}
resource "kubernetes_service_account" "pipeline_runner" {
  metadata {
    name      = "pipeline-runner"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_pipelines_runner,
      { app = "pipeline-runner" }
    )
  }
}

resource "kubernetes_cluster_role" "pipeline_runner" {
  metadata {
    name = "pipeline-runner"
    labels = merge(
      local.labels_pipelines_runner,
      { app = "pipeline-runner" }
    )
  }

  rule {
    verbs      = ["get"]
    api_groups = [""]
    resources  = ["secrets"]
  }

  rule {
    verbs      = ["get", "watch", "list"]
    api_groups = [""]
    resources  = ["configmaps"]
  }

  rule {
    verbs      = ["*"]
    api_groups = [""]
    resources  = ["persistentvolumes", "persistentvolumeclaims"]
  }

  rule {
    verbs      = ["create", "delete", "get"]
    api_groups = ["snapshot.storage.k8s.io"]
    resources  = ["volumesnapshots"]
  }

  rule {
    verbs      = ["get", "list", "watch", "update", "patch"]
    api_groups = ["argoproj.io"]
    resources  = ["workflows"]
  }

  rule {
    verbs      = ["*"]
    api_groups = [""]
    resources  = ["pods", "pods/exec", "pods/log", "services"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["", "apps", "extensions"]
    resources  = ["deployments", "replicasets"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["kubeflow.org", "serving.kubeflow.org"]
    resources  = ["*"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["batch"]
    resources  = ["jobs"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["machinelearning.seldon.io"]
    resources  = ["seldondeployments"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["networking.istio.io"]
    resources  = ["virtualservices"]
  }
}

resource "kubernetes_cluster_role_binding" "pipeline_runner" {
  metadata {
    name = "pipeline-runner"
    labels = merge(
      local.labels_pipelines_runner,
      { app = "pipeline-runner" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "pipeline-runner"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "pipeline-runner"
  }
}

locals {
  pipelines_runner_application_manifest = split("\n---\n", templatefile(
    "${path.module}/manifests/pipelines-runner-application.yaml",
    {
      namespace = kubernetes_namespace.kubeflow.metadata.0.name,
      labels    = local.labels_pipelines_runner,
    }
    )
  )
}

resource "k8s_manifest" "pipelines_runner_application" {
  count      = length(local.pipelines_runner_application_manifest)
  depends_on = [k8s_manifest.application_crds]
  content    = local.pipelines_runner_application_manifest[count.index]
}