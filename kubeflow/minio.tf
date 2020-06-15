resource "random_password" "minio_secret_access_key" {
  length  = "16"
  special = true
}

locals {
  labels_minio = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "minio"
      "app.kubernetes.io/name"      = "minio"
      "app.kubernetes.io/instance"  = "minio-0.2.5"
      "app.kubernetes.io/version"   = "0.2.5"
    }
  )
}

resource "kubernetes_config_map" "pipeline_minio_parameters" {
  metadata {
    name      = "pipeline-minio-parameters"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_minio,
      { "app" = "minio" }
    )
  }

  data = {
    minioPvcName = "minio-pv-claim"
  }
}

resource "kubernetes_secret" "mlpipeline_minio_artifact" {
  metadata {
    name      = "mlpipeline-minio-artifact"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_minio,
      { "app" = "minio" }
    )
  }

  data = {
    accesskey = "minio"
    secretkey = random_password.minio_secret_access_key.result
  }

  type = "Opaque"
}

resource "kubernetes_service" "minio_service" {
  metadata {
    name      = "minio-service"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_minio,
      { "app" = "minio" }
    )
  }

  spec {
    port {
      protocol    = "TCP"
      port        = 9000
      target_port = "9000"
    }

    selector = merge(
      local.labels_minio,
      { "app" = "minio" }
    )
  }
}

resource "kubernetes_deployment" "minio" {
  metadata {
    name      = "minio"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_minio,
      { "app" = "minio" }
    )
  }

  spec {
    selector {
      match_labels = merge(
        local.labels_minio,
        { "app" = "minio" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_minio,
          { "app" = "minio" }
        )
      }

      spec {
        automount_service_account_token = true
        volume {
          name = "data"

          persistent_volume_claim {
            claim_name = "minio-pv-claim"
          }
        }

        container {
          name  = "minio"
          image = "minio/minio:RELEASE.2018-02-09T22-40-05Z"
          args  = ["server", "/data"]

          port {
            container_port = 9000
          }

          env {
            name  = "MINIO_ACCESS_KEY"
            value = "minio"
          }

          env {
            name = "MINIO_SECRET_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mlpipeline_minio_artifact.metadata.0.name
                key  = "secretkey"
              }
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
            sub_path   = "minio"
          }
        }
      }
    }

    strategy {
      type = "Recreate"
    }
  }
}

resource "kubernetes_persistent_volume_claim" "minio_pv_claim" {
  metadata {
    name      = "minio-pv-claim"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_minio,
      { "app" = "minio" }
    )
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "20Gi"
      }
    }
  }
}

resource "k8s_manifest" "minio_application" {
  depends_on = [k8s_manifest.application_crds]

  content = templatefile(
    "${path.module}/manifests/minio-application.yaml",
    {
      namespace = kubernetes_namespace.kubeflow.metadata.0.name,
      labels    = local.labels_api_service
    }
  )
}
