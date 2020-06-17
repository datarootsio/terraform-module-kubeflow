locals {
  labels_pipelines_viewer = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "pipelines-viewer"
      "app.kubernetes.io/name"      = "pipelines-viewer"
      "app.kubernetes.io/instance"  = "pipelines-viewer-0.2.5"
      "app.kubernetes.io/version"   = "0.2.5"
    }
  )
}

resource "kubernetes_service_account" "ml_pipeline_viewer_crd_service_account" {
  metadata {
    name      = "ml-pipeline-viewer-crd-service-account"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_pipelines_viewer,
      { app = "ml-pipeline-viewer-crd" }
    )
  }
}

resource "kubernetes_cluster_role" "ml_pipeline_viewer_kubeflow_pipeline_viewers_edit" {
  metadata {
    name = "ml-pipeline-viewer-kubeflow-pipeline-viewers-edit"

    labels = merge(
      local.labels_pipelines_viewer,
      { app                                                                            = "ml-pipeline-viewer-crd"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-edit"                   = "true"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-pipeline-viewers-admin" = "true"
      }
    )
  }

  rule {
    verbs      = ["get", "list", "watch", "create", "delete", "deletecollection", "patch", "update"]
    api_groups = ["kubeflow.org"]
    resources  = ["viewers"]
  }
}

resource "kubernetes_cluster_role" "ml_pipeline_viewer_kubeflow_pipeline_viewers_view" {
  metadata {
    name = "ml-pipeline-viewer-kubeflow-pipeline-viewers-view"

    labels = merge(
      local.labels_pipelines_viewer,
      { app                                                          = "ml-pipeline-viewer-crd"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-view" = "true"
      }
    )
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["kubeflow.org"]
    resources  = ["viewers"]
  }
}

resource "kubernetes_cluster_role" "ml_pipeline_viewer_controller_role" {
  metadata {
    name = "ml-pipeline-viewer-controller-role"

    labels = merge(
      local.labels_pipelines_viewer,
      { app = "ml-pipeline-viewer-crd" }
    )
  }

  rule {
    verbs      = ["create", "get", "list", "watch", "update", "patch", "delete"]
    api_groups = ["*"]
    resources  = ["deployments", "services"]
  }

  rule {
    verbs      = ["create", "get", "list", "watch", "update", "patch", "delete"]
    api_groups = ["kubeflow.org"]
    resources  = ["viewers"]
  }
}

resource "kubernetes_cluster_role_binding" "ml_pipeline_viewer_crd_role_binding" {
  metadata {
    name = "ml-pipeline-viewer-crd-role-binding"
    labels = merge(
      local.labels_pipelines_viewer,
      { app = "ml-pipeline-viewer-crd" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "ml-pipeline-viewer-crd-service-account"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "ml-pipeline-viewer-controller-role"
  }
}

resource "kubernetes_deployment" "ml_pipeline_viewer_controller_deployment" {
  depends_on = [k8s_manifest.pipelines_viewer]
  metadata {
    name      = "ml-pipeline-viewer-controller-deployment"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_pipelines_viewer,
      { app = "ml-pipeline-viewer-crd" }
    )
  }

  spec {
    selector {
      match_labels = merge(
      local.labels_pipelines_viewer,
      { app = "ml-pipeline-viewer-crd" }
    )
    }

    template {
      metadata {
    labels = merge(
      local.labels_pipelines_viewer,
      { app = "ml-pipeline-viewer-crd" }
    )
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "ml-pipeline-viewer-controller"
          image = "gcr.io/ml-pipeline/viewer-crd-controller:0.2.5"

          env {
            name = "POD_NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          image_pull_policy = "Always"
        }

        service_account_name = "ml-pipeline-viewer-crd-service-account"
      }
    }
  }
}

locals {
  pipelines_viewer_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/pipelines-viewer-crd-application.yaml",
    {
      namespace = kubernetes_namespace.kubeflow.metadata.0.name,
      labels    = local.labels_pipelines_viewer,
    }
    )
  )
}

resource "k8s_manifest" "pipelines_viewer" {
  count      = length(local.pipelines_viewer_manifests)
  depends_on = [k8s_manifest.application_crds]
  content    = local.pipelines_viewer_manifests[count.index]
}