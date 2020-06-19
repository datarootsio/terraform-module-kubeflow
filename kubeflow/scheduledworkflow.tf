locals {
  labels_scheduledworkflow = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "scheduledworkflow"
      "app.kubernetes.io/name"      = "scheduledworkflow"
      "app.kubernetes.io/instance"  = "scheduledworkflow-0.2.5"
      "app.kubernetes.io/version"   = "0.2.5"
    }
  )
}

resource "kubernetes_service_account" "ml_pipeline_scheduledworkflow" {
  metadata {
    name      = "ml-pipeline-scheduledworkflow"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_scheduledworkflow,
      { app = "ml-pipeline-scheduledworkflow" }
    )
  }
}

resource "kubernetes_role" "ml_pipeline_scheduledworkflow" {
  metadata {
    name      = "ml-pipeline-scheduledworkflow"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_scheduledworkflow,
      { app = "ml-pipeline-scheduledworkflow" }
    )
  }

  rule {
    verbs      = ["create", "get", "list", "watch", "update", "patch", "delete"]
    api_groups = ["argoproj.io"]
    resources  = ["workflows"]
  }

  rule {
    verbs      = ["create", "get", "list", "watch", "update", "patch", "delete"]
    api_groups = ["kubeflow.org"]
    resources  = ["scheduledworkflows"]
  }
}

resource "kubernetes_cluster_role" "kubeflow_scheduledworkflows_edit" {
  metadata {
    name = "kubeflow-scheduledworkflows-edit"
    labels = merge(
      local.labels_scheduledworkflow,
      {
        app                                                                              = "ml-pipeline-scheduledworkflow"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-edit"                     = "true"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-scheduledworkflows-admin" = "true"
      }
    )
  }

  rule {
    verbs      = ["get", "list", "watch", "create", "delete", "deletecollection", "patch", "update"]
    api_groups = ["kubeflow.org"]
    resources  = ["scheduledworkflows"]
  }
}

resource "kubernetes_cluster_role" "kubeflow_scheduledworkflows_view" {
  metadata {
    name = "kubeflow-scheduledworkflows-view"
    labels = merge(
      local.labels_scheduledworkflow,
      {
        app                                                          = "ml-pipeline-scheduledworkflow"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-view" = "true"
      }
    )
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["kubeflow.org"]
    resources  = ["scheduledworkflows"]
  }
}

resource "kubernetes_cluster_role_binding" "ml_pipeline_scheduledworkflow" {
  metadata {
    name = "ml-pipeline-scheduledworkflow"
    labels = merge(
      local.labels_scheduledworkflow,
      { app = "ml-pipeline-scheduledworkflow" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "ml-pipeline-scheduledworkflow"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
}

resource "kubernetes_deployment" "ml_pipeline_scheduledworkflow" {
  depends_on = [k8s_manifest.scheduledworkflow_application_crd]
  metadata {
    name      = "ml-pipeline-scheduledworkflow"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_scheduledworkflow,
      { app = "ml-pipeline-scheduledworkflow" }
    )
  }

  spec {
    selector {
      match_labels = merge(
        local.labels_scheduledworkflow,
        { app = "ml-pipeline-scheduledworkflow" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_scheduledworkflow,
          { app = "ml-pipeline-scheduledworkflow" }
        )
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "ml-pipeline-scheduledworkflow"
          image = "gcr.io/ml-pipeline/scheduledworkflow:0.2.5"

          env {
            name = "POD_NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          image_pull_policy = "IfNotPresent"
        }

        service_account_name = "ml-pipeline-scheduledworkflow"
      }
    }
  }
}


locals {
  scheduledworkflow_application_crd_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/scheduledworkflow-application-crd.yaml",
    {
      namespace = kubernetes_namespace.kubeflow.metadata.0.name,
      labels    = local.labels_scheduledworkflow,
    }
    )
  )
}

resource "k8s_manifest" "scheduledworkflow_application_crd" {
  count      = length(local.scheduledworkflow_application_crd_manifests)
  depends_on = [k8s_manifest.application_crds]
  content    = local.scheduledworkflow_application_crd_manifests[count.index]
}