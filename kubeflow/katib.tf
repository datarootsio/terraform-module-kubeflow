locals {
  labels_katib = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "katib"
      "app.kubernetes.io/name"      = "katib"
      "app.kubernetes.io/instance"  = "katib-0.8.0"
      "app.kubernetes.io/version"   = "0.8.0"
    }
  )
}

resource "random_password" "mysql_password" {
  length  = "16"
  special = false
}


resource "kubernetes_service_account" "katib_controller" {
  metadata {
    name      = "katib-controller"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_katib
  }
}

resource "kubernetes_service_account" "katib_ui" {
  metadata {
    name      = "katib-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_katib
  }
}

resource "kubernetes_cluster_role" "katib_controller" {
  metadata {
    name   = "katib-controller"
    labels = local.labels_katib
  }

  rule {
    verbs      = ["*"]
    api_groups = [""]
    resources  = ["configmaps", "serviceaccounts", "services", "secrets", "events", "namespaces"]
  }

  rule {
    verbs      = ["*"]
    api_groups = [""]
    resources  = ["pods", "pods/log", "pods/status"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["apps"]
    resources  = ["deployments"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
  }

  rule {
    verbs      = ["create", "get"]
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["admissionregistration.k8s.io"]
    resources  = ["validatingwebhookconfigurations", "mutatingwebhookconfigurations"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["kubeflow.org"]
    resources  = ["experiments", "experiments/status", "trials", "trials/status", "suggestions", "suggestions/status"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["kubeflow.org"]
    resources  = ["tfjobs", "pytorchjobs"]
  }
}

resource "kubernetes_cluster_role" "katib_ui" {
  metadata {
    name   = "katib-ui"
    labels = local.labels_katib
  }

  rule {
    verbs      = ["*"]
    api_groups = [""]
    resources  = ["configmaps", "namespaces"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["kubeflow.org"]
    resources  = ["experiments", "trials"]
  }
}

resource "kubernetes_cluster_role" "kubeflow_katib_edit" {
  metadata {
    name = "kubeflow-katib-edit"
    labels = merge(
      local.labels_katib,
      {
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-edit"        = "true"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-katib-admin" = "true"
      }
    )
  }

  rule {
    verbs      = ["get", "list", "watch", "create", "delete", "deletecollection", "patch", "update"]
    api_groups = ["kubeflow.org"]
    resources  = ["experiments", "trials", "suggestions"]
  }
}

resource "kubernetes_cluster_role" "kubeflow_katib_view" {
  metadata {
    name = "kubeflow-katib-view"
    labels = merge(
      local.labels_katib,
      {
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-view" = "true"
      }
    )
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["kubeflow.org"]
    resources  = ["experiments", "trials", "suggestions"]
  }
}

resource "kubernetes_cluster_role_binding" "katib_controller" {
  metadata {
    name   = "katib-controller"
    labels = local.labels_katib
  }

  subject {
    kind      = "ServiceAccount"
    name      = "katib-controller"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "katib-controller"
  }
}

resource "kubernetes_cluster_role_binding" "katib_ui" {
  metadata {
    name   = "katib-ui"
    labels = local.labels_katib
  }

  subject {
    kind      = "ServiceAccount"
    name      = "katib-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "katib-ui"
  }
}

resource "kubernetes_config_map" "katib_config" {
  metadata {
    name      = "katib-config"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_katib
  }

  data = {
    metrics-collector-sidecar = templatefile("${path.module}/configs/katib-metrics-collector-sidecar.json", {})
    suggestion                = templatefile("${path.module}/configs/katib-suggestion.json", {})
  }
}

resource "kubernetes_config_map" "katib_parameters" {
  metadata {
    name      = "katib-parameters"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_katib
  }

  data = {
    clusterDomain = "cluster.local"
  }
}

resource "kubernetes_config_map" "trial_template" {
  metadata {
    name      = "trial-template"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_katib
  }

  data = {
    "defaultTrialTemplate.yaml" = templatefile("${path.module}/configs/katib-default-trial-template.yaml", {})
  }
}

resource "kubernetes_secret" "katib_controller" {
  metadata {
    name      = "katib-controller"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_katib
  }
}

resource "kubernetes_secret" "katib_mysql_secrets" {
  metadata {
    name      = "katib-mysql-secrets"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_katib
  }

  data = {
    MYSQL_ROOT_PASSWORD = random_password.mysql_password.result
  }

  type = "Opaque"
}

resource "kubernetes_service" "katib_controller" {
  metadata {
    name      = "katib-controller"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = local.labels_katib

    annotations = {
      "prometheus.io/port"   = "8080"
      "prometheus.io/scheme" = "http"
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      name        = "webhook"
      protocol    = "TCP"
      port        = 443
      target_port = "8443"
    }

    port {
      name        = "metrics"
      port        = 8080
      target_port = "8080"
    }

    selector = merge(
      local.labels_katib,
      { app = "katib-controller" }
    )
  }
}

resource "kubernetes_service" "katib_db_manager" {
  metadata {
    name      = "katib-db-manager"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_katib,
      {
        app       = "katib"
        component = "db-manager"
      }
    )
  }

  spec {
    port {
      name     = "api"
      protocol = "TCP"
      port     = 6789
    }

    selector = merge(
      local.labels_katib,
      {
        app       = "katib"
        component = "db-manager"
      }
    )

    type = "ClusterIP"
  }
}

resource "kubernetes_service" "katib_mysql" {
  metadata {
    name      = "katib-mysql"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_katib,
      {
        app       = "katib"
        component = "mysql"
      }
    )
  }

  spec {
    port {
      name     = "dbapi"
      protocol = "TCP"
      port     = 3306
    }

    selector = merge(
      local.labels_katib,
      {
        app       = "katib"
        component = "mysql"
      }
    )

    type = "ClusterIP"
  }
}

resource "kubernetes_service" "katib_ui" {
  metadata {
    name      = "katib-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_katib,
      {
        app       = "katib"
        component = "ui"
      }
    )
  }

  spec {
    port {
      name        = "ui"
      protocol    = "TCP"
      port        = 80
      target_port = "8080"
    }

    selector = merge(
      local.labels_katib,
      {
        app       = "katib"
        component = "ui"
      }
    )

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "katib_controller" {
  depends_on = [k8s_manifest.katib_crd_application_vs]
  metadata {
    name      = "katib-controller"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_katib,
      {
        app = "katib-controller"
      }
    )
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        local.labels_katib,
        {
          app = "katib-controller"
        }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_katib,
          {
            app = "katib-controller"
          }
        )

        annotations = {
          "prometheus.io/scrape"    = "true"
          "sidecar.istio.io/inject" = "false"
        }
      }

      spec {
        automount_service_account_token = true
        volume {
          name = "cert"

          secret {
            secret_name  = "katib-controller"
            default_mode = "0644"
          }
        }

        container {
          name    = "katib-controller"
          image   = "gcr.io/kubeflow-images-public/katib/v1alpha3/katib-controller:v0.8.0"
          command = ["./katib-controller"]
          args    = ["--webhook-port=8443"]

          port {
            name           = "webhook"
            container_port = 8443
            protocol       = "TCP"
          }

          port {
            name           = "metrics"
            container_port = 8080
            protocol       = "TCP"
          }

          env {
            name = "KATIB_CORE_NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          volume_mount {
            name       = "cert"
            read_only  = true
            mount_path = "/tmp/cert"
          }

          image_pull_policy = "IfNotPresent"
        }

        service_account_name = "katib-controller"
      }
    }
  }
}

resource "kubernetes_deployment" "katib_db_manager" {
  depends_on = [k8s_manifest.katib_crd_application_vs, kubernetes_deployment.katib_mysql]
  metadata {
    name      = "katib-db-manager"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_katib,
      {
        app       = "katib"
        component = "db-manager"
      }
    )
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        local.labels_katib,
        {
          app       = "katib"
          component = "db-manager"
        }
      )
    }

    template {
      metadata {
        name = "katib-db-manager"

        labels = merge(
          local.labels_katib,
          {
            app       = "katib"
            component = "db-manager"
          }
        )

        annotations = {
          "sidecar.istio.io/inject" = "false"
        }
      }

      spec {
        automount_service_account_token = true
        container {
          name    = "katib-db-manager"
          image   = "gcr.io/kubeflow-images-public/katib/v1alpha3/katib-db-manager:v0.8.0"
          command = ["./katib-db-manager"]

          port {
            name           = "api"
            container_port = 6789
          }

          env {
            name  = "DB_NAME"
            value = "mysql"
          }

          env {
            name = "DB_PASSWORD"

            value_from {
              secret_key_ref {
                name = "katib-mysql-secrets"
                key  = "MYSQL_ROOT_PASSWORD"
              }
            }
          }

          liveness_probe {
            exec {
              command = ["/bin/grpc_health_probe", "-addr=:6789"]
            }

            initial_delay_seconds = 10
            period_seconds        = 60
            failure_threshold     = 5
          }

          readiness_probe {
            exec {
              command = ["/bin/grpc_health_probe", "-addr=:6789"]
            }

            initial_delay_seconds = 5
          }

          image_pull_policy = "IfNotPresent"
        }
      }
    }
  }
}

resource "kubernetes_deployment" "katib_mysql" {
  depends_on = [k8s_manifest.katib_crd_application_vs]
  metadata {
    name      = "katib-mysql"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_katib,
      {
        app       = "katib"
        component = "mysql"
      }
    )
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        local.labels_katib,
        {
          app       = "katib"
          component = "mysql"
        }
      )
    }

    template {
      metadata {
        name = "katib-mysql"

        labels = merge(
          local.labels_katib,
          {
            app       = "katib"
            component = "mysql"
          }
        )

        annotations = {
          "sidecar.istio.io/inject" = "false"
        }
      }

      spec {
        automount_service_account_token = true
        volume {
          name = "katib-mysql"

          persistent_volume_claim {
            claim_name = "katib-mysql"
          }
        }

        container {
          name  = "katib-mysql"
          image = "mysql:8"
          args  = ["--datadir", "/var/lib/mysql/datadir"]

          port {
            name           = "dbapi"
            container_port = 3306
          }

          env {
            name = "MYSQL_ROOT_PASSWORD"

            value_from {
              secret_key_ref {
                name = "katib-mysql-secrets"
                key  = "MYSQL_ROOT_PASSWORD"
              }
            }
          }

          env {
            name  = "MYSQL_ALLOW_EMPTY_PASSWORD"
            value = "true"
          }

          env {
            name  = "MYSQL_DATABASE"
            value = "katib"
          }

          volume_mount {
            name       = "katib-mysql"
            mount_path = "/var/lib/mysql"
          }

          liveness_probe {
            exec {
              command = ["/bin/bash", "-c", "mysqladmin ping -u root -p$${MYSQL_ROOT_PASSWORD}"]
            }

            initial_delay_seconds = 30
            timeout_seconds       = 5
            period_seconds        = 10
          }

          readiness_probe {
            exec {
              command = ["/bin/bash", "-c", "mysql -D $${MYSQL_DATABASE} -u root -p$${MYSQL_ROOT_PASSWORD} -e 'SELECT 1'"]
            }

            initial_delay_seconds = 5
            timeout_seconds       = 1
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "katib_ui" {
  depends_on = [k8s_manifest.katib_crd_application_vs]
  metadata {
    name      = "katib-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_katib,
      {
        app       = "katib"
        component = "ui"
      }
    )
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        local.labels_katib,
        {
          app       = "katib"
          component = "ui"
        }
      )
    }

    template {
      metadata {
        name = "katib-ui"

        labels = merge(
          local.labels_katib,
          {
            app       = "katib"
            component = "ui"
          }
        )
      }

      spec {
        automount_service_account_token = true
        container {
          name    = "katib-ui"
          image   = "gcr.io/kubeflow-images-public/katib/v1alpha3/katib-ui:v0.8.0"
          command = ["./katib-ui"]
          args    = ["--port=8080"]

          port {
            name           = "ui"
            container_port = 8080
          }

          env {
            name = "KATIB_CORE_NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          image_pull_policy = "IfNotPresent"
        }

        service_account_name = "katib-ui"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "katib_mysql" {
  metadata {
    name      = "katib-mysql"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_katib
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
  katib_crd_application_vs_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/katib-crd-application-vs.yaml",
    {
      labels      = local.labels_katib,
      domain_name = var.domain_name,
      namespace   = kubernetes_namespace.kubeflow.metadata.0.name
    }
    )
  )
}

resource "k8s_manifest" "katib_crd_application_vs" {
  count      = length(local.katib_crd_application_vs_manifests)
  depends_on = [k8s_manifest.application_crds, var.kubeflow_depends_on]
  content    = local.katib_crd_application_vs_manifests[count.index]
}