resource "random_password" "metadata_mysql_password" {
  length  = "16"
  special = false
}

locals {
  labels_metadata = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "metadata"
      "app.kubernetes.io/name"      = "metadata"
      "app.kubernetes.io/instance"  = "metadata-0.2.1"
      "app.kubernetes.io/version"   = "0.2.1"
    }
  )
}

resource "kubernetes_service_account" "metadata_ui" {
  metadata {
    name      = "metadata-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_metadata
  }
}

resource "kubernetes_role" "metadata_ui" {
  metadata {
    name      = "metadata-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_metadata,
      { app = "metadata-ui" }
    )
  }

  rule {
    verbs      = ["create", "get", "list"]
    api_groups = [""]
    resources  = ["pods", "pods/log"]
  }

  rule {
    verbs      = ["create", "get", "list", "watch", "delete"]
    api_groups = ["kubeflow.org"]
    resources  = ["viewers"]
  }
}

resource "kubernetes_role_binding" "metadata_ui" {
  metadata {
    name      = "metadata-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_metadata,
      { app = "metadata-ui" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "metadata-ui"
  }
}

resource "kubernetes_config_map" "metadata_db_parameters" {
  metadata {
    name      = "metadata-db-parameters"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_metadata
  }

  data = {
    MYSQL_ALLOW_EMPTY_PASSWORD = "true"
    MYSQL_DATABASE             = "metadb"
    MYSQL_PORT                 = "3306"
  }
}

resource "kubernetes_config_map" "metadata_grpc_configmap" {
  metadata {
    name      = "metadata-grpc-configmap"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_metadata
  }

  data = {
    METADATA_GRPC_SERVICE_HOST = "metadata-grpc-service"

    METADATA_GRPC_SERVICE_PORT = "8080"
  }
}

resource "kubernetes_config_map" "metadata_ui_parameters" {
  metadata {
    name      = "metadata-ui-parameters"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_metadata
  }

  data = {
    uiClusterDomain = "cluster.local"
  }
}

resource "kubernetes_secret" "metadata_db_secrets" {
  metadata {
    name      = "metadata-db-secrets"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_metadata
  }

  data = {
    MYSQL_ROOT_PASSWORD = random_password.metadata_mysql_password.result
    MYSQL_USER_NAME     = "root"
  }

  type = "Opaque"
}

resource "kubernetes_service" "metadata_db" {
  metadata {
    name      = "metadata-db"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_metadata,
      { component = "db" }
    )
  }

  spec {
    port {
      name     = "dbapi"
      protocol = "TCP"
      port     = 3306
    }

    selector = merge(
      local.labels_metadata,
      { component = "db" }
    )

    type = "ClusterIP"
  }
}

resource "kubernetes_service" "metadata_envoy_service" {
  metadata {
    name      = "metadata-envoy-service"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_metadata,
      { app = "metadata" }
    )
  }

  spec {
    port {
      name     = "md-envoy"
      protocol = "TCP"
      port     = 9090
    }

    selector = merge(
      local.labels_metadata,
      { component = "envoy" }
    )

    type = "ClusterIP"
  }
}

resource "kubernetes_service" "metadata_grpc_service" {
  metadata {
    name      = "metadata-grpc-service"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_metadata,
      { app = "grpc-metadata" }
    )
  }

  spec {
    port {
      name     = "grpc-backendapi"
      protocol = "TCP"
      port     = 8080
    }

    selector = merge(
      local.labels_metadata,
      { component = "grpc-server" }
    )

    type = "ClusterIP"
  }
}

resource "kubernetes_service" "metadata_service" {
  metadata {
    name      = "metadata-service"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_metadata,
      { app = "metadata" }
    )
  }

  spec {
    port {
      name     = "backendapi"
      protocol = "TCP"
      port     = 8080
    }

    selector = merge(
      local.labels_metadata,
      { component = "server" }
    )

    type = "ClusterIP"
  }
}

resource "kubernetes_service" "metadata_ui" {
  metadata {
    name      = "metadata-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_metadata,
      { app = "metadata-ui" }
    )
  }

  spec {
    port {
      port        = 80
      target_port = "3000"
    }

    selector = merge(
      local.labels_metadata,
      { app = "metadata-ui" }
    )
  }
}

resource "kubernetes_deployment" "metadata_db" {
  depends_on = [k8s_manifest.metadata_application_vs]
  metadata {
    name      = "metadata-db"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_metadata,
      { component = "db" }
    )
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        local.labels_metadata,
        { component = "db" }
      )
    }

    template {
      metadata {
        name = "db"
        labels = merge(
          local.labels_metadata,
          { component = "db" }
        )
      }

      spec {
        automount_service_account_token = true
        volume {
          name = "metadata-mysql"

          persistent_volume_claim {
            claim_name = "metadata-mysql"
          }
        }

        container {
          name  = "db-container"
          image = "mysql:8.0.3"
          args  = ["--datadir", "/var/lib/mysql/datadir"]

          port {
            name           = "dbapi"
            container_port = 3306
          }

          env_from {
            config_map_ref {
              name = "metadata-db-parameters"
            }
          }

          env_from {
            secret_ref {
              name = "metadata-db-secrets"
            }
          }

          volume_mount {
            name       = "metadata-mysql"
            mount_path = "/var/lib/mysql"
          }

          readiness_probe {
            exec {
              command = ["/bin/bash", "-c", "mysql -D $$MYSQL_DATABASE -p$$MYSQL_ROOT_PASSWORD -e 'SELECT 1'"]
            }

            initial_delay_seconds = 5
            timeout_seconds       = 1
            period_seconds        = 2
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "metadata_deployment" {
  depends_on = [k8s_manifest.metadata_application_vs]
  timeouts {
    create = "20m"
  }
  metadata {
    name      = "metadata-deployment"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_metadata,
      { component = "server" }
    )
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        local.labels_metadata,
        { component = "server" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_metadata,
          { component = "server" }
        )
      }

      spec {
        automount_service_account_token = true
        container {
          name    = "container"
          image   = "gcr.io/kubeflow-images-public/metadata:v0.1.11"
          command = ["./server/server", "--http_port=8080", "--mysql_service_host=metadata-db", "--mysql_service_port=$(MYSQL_PORT)", "--mysql_service_user=$(MYSQL_USER_NAME)", "--mysql_service_password=$(MYSQL_ROOT_PASSWORD)", "--mlmd_db_name=$(MYSQL_DATABASE)"]

          port {
            name           = "backendapi"
            container_port = 8080
          }

          env_from {
            config_map_ref {
              name = "metadata-db-parameters"
            }
          }

          env_from {
            secret_ref {
              name = "metadata-db-secrets"
            }
          }

          readiness_probe {
            http_get {
              path = "/api/v1alpha1/artifact_types"
              port = "backendapi"

              http_header {
                name  = "ContentType"
                value = "application/json"
              }
            }

            initial_delay_seconds = 3
            timeout_seconds       = 2
            period_seconds        = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "metadata_envoy_deployment" {
  depends_on = [k8s_manifest.metadata_application_vs]
  metadata {
    name      = "metadata-envoy-deployment"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_metadata,
      { component = "envoy" }
    )
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        local.labels_metadata,
        { component = "envoy" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_metadata,
          { component = "envoy" }
        )
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "container"
          image = "gcr.io/ml-pipeline/envoy:metadata-grpc"

          port {
            name           = "md-envoy"
            container_port = 9090
          }

          port {
            name           = "envoy-admin"
            container_port = 9901
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "metadata_grpc_deployment" {
  metadata {
    name      = "metadata-grpc-deployment"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_metadata,
      { component = "grpc-server" }
    )
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        local.labels_metadata,
        { component = "grpc-server" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_metadata,
          { component = "grpc-server" }
        )
      }

      spec {
        automount_service_account_token = true
        container {
          name    = "container"
          image   = "gcr.io/tfx-oss-public/ml_metadata_store_server:v0.21.1"
          command = ["/bin/metadata_store_server"]
          args    = ["--grpc_port=$(METADATA_GRPC_SERVICE_PORT)", "--mysql_config_host=metadata-db", "--mysql_config_database=$(MYSQL_DATABASE)", "--mysql_config_port=$(MYSQL_PORT)", "--mysql_config_user=$(MYSQL_USER_NAME)", "--mysql_config_password=$(MYSQL_ROOT_PASSWORD)"]

          port {
            name           = "grpc-backendapi"
            container_port = 8080
          }

          env_from {
            config_map_ref {
              name = "metadata-db-parameters"
            }
          }

          env_from {
            secret_ref {
              name = "metadata-db-secrets"
            }
          }

          env_from {
            config_map_ref {
              name = "metadata-grpc-configmap"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "metadata_ui" {
  depends_on = [k8s_manifest.metadata_application_vs]
  metadata {
    name      = "metadata-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_metadata,
      { app = "metadata-ui" }
    )
  }

  spec {
    selector {
      match_labels = merge(
        local.labels_metadata,
        { app = "metadata-ui" }
      )
    }

    template {
      metadata {
        name = "ui"

        labels = merge(
          local.labels_metadata,
          { app = "metadata-ui" }
        )
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "metadata-ui"
          image = "gcr.io/kubeflow-images-public/metadata-frontend:v0.1.8"

          port {
            container_port = 3000
          }

          image_pull_policy = "IfNotPresent"
        }

        service_account_name = "metadata-ui"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "metadata_mysql" {
  metadata {
    name      = "metadata-mysql"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_metadata
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

locals {
  metadata_application_vs_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/metadata-application-vs.yaml",
    {
      labels      = local.labels_metadata,
      domain_name = var.domain_name,
      namespace   = kubernetes_namespace.kubeflow.metadata.0.name
    }
    )
  )
}

resource "k8s_manifest" "metadata_application_vs" {
  count      = length(local.metadata_application_vs_manifests)
  depends_on = [k8s_manifest.application_crds, var.kubeflow_depends_on]
  content    = local.metadata_application_vs_manifests[count.index]
}