locals {
  labels_webhook = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "webhook"
      "app.kubernetes.io/name"      = "webhook"
      "app.kubernetes.io/instance"  = "webhook-v1.0.0"
      "app.kubernetes.io/version"   = "v1.0.0"
    }
  )
}

resource "kubernetes_service_account" "admission_webhook_service_account" {
  metadata {
    name      = "admission-webhook-service-account"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_webhook,
      { app = "admission-webhook" }
    )
  }
}

resource "kubernetes_cluster_role" "admission_webhook_cluster_role" {
  metadata {
    name = "admission-webhook-cluster-role"
    labels = merge(
      local.labels_webhook,
      { app = "admission-webhook" }
    )
  }

  rule {
    verbs      = ["get", "watch", "list", "update", "create", "patch", "delete"]
    api_groups = ["kubeflow.org"]
    resources  = ["poddefaults"]
  }
}

resource "kubernetes_cluster_role" "admission_webhook_kubeflow_poddefaults_view" {
  metadata {
    name = "admission-webhook-kubeflow-poddefaults-view"

    labels = merge(
      local.labels_webhook,
      {
        app                                                                       = "admission-webhook"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-poddefaults-admin" = "true"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-poddefaults-edit"  = "true"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-view"              = "true"
      }
    )
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["kubeflow.org"]
    resources  = ["poddefaults"]
  }
}

resource "kubernetes_cluster_role_binding" "admission_webhook_cluster_role_binding" {
  metadata {
    name = "admission-webhook-cluster-role-binding"
    labels = merge(
      local.labels_webhook,
      { app = "admission-webhook" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "admission-webhook-service-account"
    namespace = "kubeflow"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admission-webhook-cluster-role"
  }
}

resource "kubernetes_config_map" "admission_webhook_admission_webhook_parameters" {
  metadata {
    name      = "admission-webhook-admission-webhook-parameters"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_webhook,
      { app = "admission-webhook" }
    )
  }

  data = {
    issuer = "kubeflow-self-signing-issuer"

    namespace = "kubeflow"
  }
}

resource "kubernetes_service" "admission_webhook_service" {
  metadata {
    name      = "admission-webhook-service"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_webhook,
      { app = "admission-webhook" }
    )
  }

  spec {
    port {
      port        = 443
      target_port = "443"
    }

    selector = merge(
      local.labels_webhook,
      { app = "admission-webhook" }
    )
  }
}

resource "kubernetes_deployment" "admission_webhook_deployment" {
  depends_on = [k8s_manifest.webhook_crd_application]
  metadata {
    name      = "admission-webhook-deployment"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_webhook,
      { app = "admission-webhook" }
    )
  }

  spec {
    selector {
      match_labels = merge(
        local.labels_webhook,
        { app = "admission-webhook" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_webhook,
          { app = "admission-webhook" }
        )
      }

      spec {
        automount_service_account_token = true
        volume {
          name = "webhook-cert"

          secret {
            secret_name = "webhook-certs"
          }
        }

        container {
          name  = "admission-webhook"
          image = "gcr.io/kubeflow-images-public/admission-webhook:v1.0.0-gaf96e4e3"
          args  = ["--tlsCertFile=/etc/webhook/certs/tls.crt", "--tlsKeyFile=/etc/webhook/certs/tls.key"]

          volume_mount {
            name       = "webhook-cert"
            read_only  = true
            mount_path = "/etc/webhook/certs"
          }
        }

        service_account_name = "admission-webhook-service-account"
      }
    }
  }
}

locals {
  webhook_crd_application_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/webhook-crd-application.yaml",
    {
      namespace = kubernetes_namespace.kubeflow.metadata.0.name,
      labels    = local.labels_webhook,
    }
    )
  )
}

resource "k8s_manifest" "webhook_crd_application" {
  count      = length(local.webhook_crd_application_manifests)
  depends_on = [k8s_manifest.application_crds, var.kubeflow_depends_on]
  content    = local.webhook_crd_application_manifests[count.index]
}