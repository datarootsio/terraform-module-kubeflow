locals {
  labels_notebook_controller = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "notebook-controller"
      "app.kubernetes.io/name"      = "notebook-controller"
      "app.kubernetes.io/instance"  = "notebook-controller-v1.0.0"
      "app.kubernetes.io/version"   = "v1.0.0"
    }
  )
}

resource "kubernetes_service_account" "notebook_controller_service_account" {
  metadata {
    name      = "notebook-controller-service-account"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_notebook_controller,
      { app = "notebook-controller" }
    )
  }
}

resource "kubernetes_cluster_role" "notebook_controller_kubeflow_notebooks_edit" {
  metadata {
    name = "notebook-controller-kubeflow-notebooks-edit"


    labels = merge(
      local.labels_notebook_controller,
      {
        app                                                                     = "notebook-controller"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-edit"            = "true"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-notebooks-admin" = "true"
      }
    )
  }

  rule {
    verbs      = ["get", "list", "watch", "create", "delete", "deletecollection", "patch", "update"]
    api_groups = ["kubeflow.org"]
    resources  = ["notebooks", "notebooks/status"]
  }
}

resource "kubernetes_cluster_role" "notebook_controller_kubeflow_notebooks_view" {
  metadata {
    name = "notebook-controller-kubeflow-notebooks-view"

    labels = merge(
      local.labels_notebook_controller,
      {
        app                                                          = "notebook-controller"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-view" = "true"
      }
    )
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["kubeflow.org"]
    resources  = ["notebooks", "notebooks/status"]
  }
}

resource "kubernetes_cluster_role" "notebook_controller_role" {
  metadata {
    name = "notebook-controller-role"
    labels = merge(
      local.labels_notebook_controller,
      { app = "notebook-controller" }
    )
  }

  rule {
    verbs      = ["*"]
    api_groups = ["apps"]
    resources  = ["statefulsets", "deployments"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["pods"]
  }

  rule {
    verbs      = ["*"]
    api_groups = [""]
    resources  = ["services"]
  }

  rule {
    verbs      = ["get", "list", "watch", "create"]
    api_groups = [""]
    resources  = ["events"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["kubeflow.org"]
    resources  = ["notebooks", "notebooks/status", "notebooks/finalizers"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["networking.istio.io"]
    resources  = ["virtualservices"]
  }
}

resource "kubernetes_cluster_role_binding" "notebook_controller_role_binding" {
  metadata {
    name = "notebook-controller-role-binding"

    labels = merge(
      local.labels_notebook_controller,
      { app = "notebook-controller" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "notebook-controller-service-account"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "notebook-controller-role"
  }
}

resource "kubernetes_config_map" "notebook_controller_parameters" {
  metadata {
    name      = "notebook-controller-parameters"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_notebook_controller,
      { app = "notebook-controller" }
    )
  }

  data = {
    ISTIO_GATEWAY = "${kubernetes_namespace.kubeflow.metadata.0.name}/kubeflow-gateway"
    POD_LABELS    = "gcp-cred-secret=user-gcp-sa,gcp-cred-secret-filename=user-gcp-sa.json"
    USE_ISTIO     = "true"
  }
}

resource "kubernetes_service" "notebook_controller_service" {
  metadata {
    name      = "notebook-controller-service"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_notebook_controller,
      { app = "notebook-controller" }
    )
  }

  spec {
    port {
      port = 443
    }

    selector = merge(
      local.labels_notebook_controller,
      { app = "notebook-controller" }
    )
  }
}

resource "kubernetes_deployment" "notebook_controller_deployment" {
  depends_on = [k8s_manifest.notebook_controller]
  metadata {
    name      = "notebook-controller-deployment"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_notebook_controller,
      { app = "notebook-controller" }
    )
  }

  spec {
    selector {
      match_labels = merge(
        local.labels_notebook_controller,
        { app = "notebook-controller" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_notebook_controller,
          { app = "notebook-controller" }
        )
      }

      spec {
        automount_service_account_token = true
        container {
          name    = "manager"
          image   = "gcr.io/kubeflow-images-public/notebook-controller:v1.0.0-gcd65ce25"
          command = ["/manager"]

          env {
            name = "USE_ISTIO"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.notebook_controller_parameters.metadata.0.name
                key  = "USE_ISTIO"
              }
            }
          }

          env {
            name = "ISTIO_GATEWAY"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.notebook_controller_parameters.metadata.0.name
                key  = "ISTIO_GATEWAY"
              }
            }
          }

          env {
            name = "POD_LABELS"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.notebook_controller_parameters.metadata.0.name
                key  = "POD_LABELS"
              }
            }
          }

          liveness_probe {
            http_get {
              path = "/metrics"
              port = "8080"
            }

            initial_delay_seconds = 30
            period_seconds        = 30
          }

          image_pull_policy = "Always"
        }

        service_account_name = "notebook-controller-service-account"
      }
    }
  }
}

locals {
  notebook_controller_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/notebook-controller-application-crd.yaml",
    {
      namespace = kubernetes_namespace.kubeflow.metadata.0.name,
      labels    = local.labels_notebook_controller,
    }
    )
  )
}

resource "k8s_manifest" "notebook_controller" {
  count      = length(local.notebook_controller_manifests)
  depends_on = [k8s_manifest.application_crds]
  content    = local.notebook_controller_manifests[count.index]
}