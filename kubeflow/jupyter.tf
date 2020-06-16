locals {
  labels_jupyter = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "jupyter-web-app"
      "app.kubernetes.io/name"      = "jupyter-web-app"
      "app.kubernetes.io/instance"  = "jupyter-web-app-v1.0.0"
      "app.kubernetes.io/version"   = "v1.0.0"
    }
  )
}

resource "kubernetes_service_account" "jupyter_web_app_service_account" {
  metadata {
    name      = "jupyter-web-app-service-account"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_jupyter,
      { app = "jupyter-web-app" }
    )
  }
}

resource "kubernetes_role" "jupyter_web_app_jupyter_notebook_role" {
  metadata {
    name      = "jupyter-web-app-jupyter-notebook-role"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_jupyter,
      { app = "jupyter-web-app" }
    )
  }

  rule {
    verbs      = ["*"]
    api_groups = [""]
    resources  = ["pods", "pods/log", "secrets", "services"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["", "apps", "extensions"]
    resources  = ["deployments", "replicasets"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["kubeflow.org"]
    resources  = ["*"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["batch"]
    resources  = ["jobs"]
  }
}

resource "kubernetes_cluster_role" "jupyter_web_app_cluster_role" {
  metadata {
    name = "jupyter-web-app-cluster-role"

    labels = merge(
      local.labels_jupyter,
      { app = "jupyter-web-app" }
    )
  }

  rule {
    verbs      = ["get", "list", "create", "delete"]
    api_groups = [""]
    resources  = ["namespaces"]
  }

  rule {
    verbs      = ["create"]
    api_groups = ["authorization.k8s.io"]
    resources  = ["subjectaccessreviews"]
  }

  rule {
    verbs      = ["get", "list", "create", "delete"]
    api_groups = ["kubeflow.org"]
    resources  = ["notebooks", "notebooks/finalizers", "poddefaults"]
  }

  rule {
    verbs      = ["create", "delete", "get", "list"]
    api_groups = [""]
    resources  = ["persistentvolumeclaims"]
  }

  rule {
    verbs      = ["list"]
    api_groups = [""]
    resources  = ["events"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses"]
  }
}

resource "kubernetes_cluster_role" "jupyter_web_app_kubeflow_notebook_ui_edit" {
  metadata {
    name = "jupyter-web-app-kubeflow-notebook-ui-edit"

    labels = merge(
      local.labels_jupyter,
      {
        app                                                                  = "jupyter-web-app"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-edit"         = "true"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-tfjobs-admin" = "true"
      }
    )
  }

  rule {
    verbs      = ["get", "list", "create", "delete"]
    api_groups = ["kubeflow.org"]
    resources  = ["notebooks", "notebooks/finalizers", "poddefaults"]
  }
}

resource "kubernetes_cluster_role" "jupyter_web_app_kubeflow_notebook_ui_view" {
  metadata {
    name = "jupyter-web-app-kubeflow-notebook-ui-view"

    labels = merge(
      local.labels_jupyter,
      {
        app                                                          = "jupyter-web-app"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-view" = "true"
      }
    )
  }

  rule {
    verbs      = ["get", "list"]
    api_groups = ["kubeflow.org"]
    resources  = ["notebooks", "notebooks/finalizers", "poddefaults"]
  }

  rule {
    verbs      = ["list"]
    api_groups = [""]
    resources  = ["events"]
  }
}

resource "kubernetes_role_binding" "jupyter_web_app_jupyter_notebook_role_binding" {
  metadata {
    name      = "jupyter-web-app-jupyter-notebook-role-binding"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_jupyter,
      { app = "jupyter-web-app" }
    )
  }

  subject {
    kind = "ServiceAccount"
    name = "jupyter-notebook"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "jupyter-web-app-jupyter-notebook-role"
  }
}

resource "kubernetes_cluster_role_binding" "jupyter_web_app_cluster_role_binding" {
  metadata {
    name = "jupyter-web-app-cluster-role-binding"

    labels = merge(
      local.labels_jupyter,
      { app = "jupyter-web-app" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "jupyter-web-app-service-account"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "jupyter-web-app-cluster-role"
  }
}

resource "kubernetes_config_map" "jupyter_web_app_config" {
  metadata {
    name      = "jupyter-web-app-config"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_jupyter,
      { app = "jupyter-web-app" }
    )
  }

  data = {
    "spawner_ui_config.yaml" = templatefile("${path.module}/configs/jupyter-web-app.yaml", {})
  }
}

resource "kubernetes_config_map" "jupyter_web_app_parameters" {
  metadata {
    name      = "jupyter-web-app-parameters"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_jupyter,
      { app = "jupyter-web-app" }
    )
  }

  data = {
    ROK_SECRET_NAME = "secret-rok-{username}"
    UI              = "default"
    clusterDomain   = "cluster.local"
    policy          = "Always"
    prefix          = "jupyter"
    userid-header   = "kubeflow-userid"
  }
}

resource "kubernetes_service" "jupyter_web_app_service" {
  metadata {
    name      = "jupyter-web-app-service"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_jupyter,
      {
        app = "jupyter-web-app",
        run = "jupyter-web-app"
      }
    )

    annotations = {
      "getambassador.io/config" = "---\napiVersion: ambassador/v0\nkind:  Mapping\nname: webapp_mapping\nprefix: /jupyter/\nservice: jupyter-web-app-service.kubeflow\nadd_request_headers:\n  x-forwarded-prefix: /jupyter"
    }
  }

  spec {
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = "5000"
    }

    selector = merge(
      local.labels_jupyter,
      { app = "jupyter-web-app" }
    )

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "jupyter_web_app_deployment" {
  depends_on = [k8s_manifest.jupyter_application_vs]
  metadata {
    name      = "jupyter-web-app-deployment"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_jupyter,
      { app = "jupyter-web-app" }
    )
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        local.labels_jupyter,
        { app = "jupyter-web-app" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_jupyter,
          { app = "jupyter-web-app" }
        )
      }

      spec {
        automount_service_account_token = true
        volume {
          name = "config-volume"
          config_map {
            name = "jupyter-web-app-config"
          }
        }

        container {
          name  = "jupyter-web-app"
          image = "gcr.io/kubeflow-images-public/jupyter-web-app:v1.0.0-g2bd63238"

          port {
            container_port = 5000
          }

          env {
            name = "ROK_SECRET_NAME"
            value_from {
              config_map_key_ref {
                name = "jupyter-web-app-parameters"
                key  = "ROK_SECRET_NAME"
              }
            }
          }

          env {
            name = "UI"
            value_from {
              config_map_key_ref {
                name = "jupyter-web-app-parameters"
                key  = "UI"
              }
            }
          }

          env {
            name = "USERID_HEADER"
            value_from {
              config_map_key_ref {
                name = "jupyter-web-app-parameters"
                key  = "userid-header"
              }
            }
          }

          env {
            name = "USERID_PREFIX"
          }

          volume_mount {
            name       = "config-volume"
            mount_path = "/etc/config"
          }

          image_pull_policy = "Always"
        }

        service_account_name = "jupyter-web-app-service-account"
      }
    }
  }
}

locals {
  jupyter_application_vs_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/jupyter-application-vs.yaml",
    {
      labels      = local.labels_centraldashboard,
      domain_name = var.domain_name,
      namespace   = kubernetes_namespace.kubeflow.metadata.0.name
    }
    )
  )
}

resource "k8s_manifest" "jupyter_application_vs" {
  count      = length(local.jupyter_application_vs_manifests)
  depends_on = [k8s_manifest.application_crds, var.kubeflow_depends_on]
  content    = local.jupyter_application_vs_manifests[count.index]
}