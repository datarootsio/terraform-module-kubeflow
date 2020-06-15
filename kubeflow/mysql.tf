locals {
  labels_mysql = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "mysql"
      "app.kubernetes.io/name"      = "mysql"
      "app.kubernetes.io/instance"  = "mysql-0.2.5"
      "app.kubernetes.io/version"   = "0.2.5"
    }
  )
}

resource "kubernetes_config_map" "pipeline_mysql_parameters" {
  metadata {
    name      = "pipeline-mysql-parameters"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_mysql,
      { "app" = "mysql" }
    )
  }

  data = {
    mysqlPvcName = "mysql-pv-claim"
  }
}

resource "kubernetes_service" "mysql" {
  metadata {
    name      = "mysql"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_mysql,
      { "app" = "mysql" }
    )
  }

  spec {
    port {
      port = 3306
    }

    selector = merge(
      local.labels_mysql,
      { "app" = "mysql" }
    )
  }
}

resource "kubernetes_deployment" "mysql" {
  metadata {
    name      = "mysql"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_mysql,
      { "app" = "mysql" }
    )
  }

  spec {
    selector {
      match_labels = merge(
        local.labels_mysql,
        { "app" = "mysql" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_mysql,
          { "app" = "mysql" }
        )
      }

      spec {
        volume {
          name = "mysql-persistent-storage"

          persistent_volume_claim {
            claim_name = "mysql-pv-claim"
          }
        }

        container {
          name  = "mysql"
          image = "mysql:5.6"

          port {
            name           = "mysql"
            container_port = 3306
          }

          env {
            name  = "MYSQL_ALLOW_EMPTY_PASSWORD"
            value = "true"
          }

          volume_mount {
            name       = "mysql-persistent-storage"
            mount_path = "/var/lib/mysql"
          }
        }
      }
    }

    strategy {
      type = "Recreate"
    }
  }
}

resource "kubernetes_persistent_volume_claim" "mysql_pv_claim" {
  metadata {
    name      = "mysql-pv-claim"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_mysql,
      { "app" = "mysql" }
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

resource "k8s_manifest" "mysql_application" {
  depends_on = [k8s_manifest.application_crds]

  content = templatefile(
    "${path.module}/manifests/mysql-application.yaml",
    {
      namespace = kubernetes_namespace.kubeflow.metadata.0.name,
      labels    = local.labels_mysql
    }
  )
}