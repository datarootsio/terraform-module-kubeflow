locals {
  labels_api_service = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "api-service"
      "app.kubernetes.io/name"      = "api-service"
      "app.kubernetes.io/instance"  = "api-service-0.2.5"
      "app.kubernetes.io/version"   = "0.2.5"
    }
  )
}

resource "kubernetes_service_account" "ml_pipeline" {
  metadata {
    name      = "ml-pipeline"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_api_service,
      { app = "ml-pipeline" }
    )
  }
}

resource "kubernetes_role" "ml_pipeline" {
  metadata {
    name      = "ml-pipeline"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_api_service,
      { app = "ml-pipeline" }
    )
  }

  rule {
    verbs      = ["create", "get", "list", "watch", "update", "patch", "delete"]
    api_groups = ["argoproj.io"]
    resources  = ["workflows"]
  }

  rule {
    verbs      = ["create", "get", "list", "update", "patch", "delete"]
    api_groups = ["kubeflow.org"]
    resources  = ["scheduledworkflows"]
  }

  rule {
    verbs      = ["delete"]
    api_groups = [""]
    resources  = ["pods"]
  }
}

resource "kubernetes_role_binding" "ml_pipeline" {
  metadata {
    name      = "ml-pipeline"
    namespace = "kubeflow"

    labels = merge(
      local.labels_api_service,
      { app = "ml-pipeline" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "ml-pipeline"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "ml-pipeline"
  }
}

resource "kubernetes_secret" "ml_pipeline_config" {
  metadata {
    name      = "ml-pipeline-config"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_api_service,
      { app = "ml-pipeline" }
    )
  }

  data = {
    "config.json" = templatefile("${path.module}/configs/api-server.json",
      {
        access_key        = "minio",
        secret_access_key = random_password.minio_secret_access_key.result
      }
    )
  }
}

resource "kubernetes_service" "ml_pipeline" {
  metadata {
    name      = "ml-pipeline"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_api_service,
      { app = "ml-pipeline" }
    )
  }

  spec {
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 8888
      target_port = "8888"
    }

    port {
      name        = "grpc"
      protocol    = "TCP"
      port        = 8887
      target_port = "8887"
    }

    selector = local.labels_api_service
  }
}

resource "kubernetes_deployment" "ml_pipeline" {
  metadata {
    name      = "ml-pipeline"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_api_service,
      { "app" = "ml-pipeline" }
    )
  }

  spec {
    selector {
      match_labels = local.labels_api_service
    }

    template {
      metadata {
        labels = merge(
          local.labels_api_service,
          {
            "app" = "ml-pipeline"
          }
        )
      }

      spec {
        automount_service_account_token = true

        volume {
          name = "config-volume"
          secret {
            secret_name = "ml-pipeline-config"
          }
        }

        container {
          name    = "ml-pipeline-api-server"
          image   = "gcr.io/ml-pipeline/api-server:0.2.5"
          command = ["apiserver", "--config=/etc/ml-pipeline-config", "--sampleconfig=/config/sample_config.json", "-logtostderr=true"]

          port {
            container_port = 8888
          }

          port {
            container_port = 8887
          }

          env {
            name = "POD_NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          volume_mount {
            name       = "config-volume"
            mount_path = "/etc/ml-pipeline-config"
          }

          image_pull_policy = "IfNotPresent"
        }

        service_account_name = "ml-pipeline"
      }
    }
  }
}

locals {
  api_service_application_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/api-service-application.yaml",
    {
      namespace = kubernetes_namespace.kubeflow.metadata.0.name,
      labels    = local.labels_api_service
    }
    )
  )
}

resource "k8s_manifest" "api_service_application" {
  count      = length(local.api_service_application_manifests)
  depends_on = [k8s_manifest.application_crds]
  content    = local.api_service_application_manifests[count.index]
}

