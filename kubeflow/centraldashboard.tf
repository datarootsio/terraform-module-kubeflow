locals {
  labels_centraldashboard = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "centraldashboard"
      "app.kubernetes.io/name"      = "centraldashboard"
      "app.kubernetes.io/instance"  = "centraldashboard-v1.0.0"
      "app.kubernetes.io/version"   = "v1.0.0"
    }
  )
}

resource "kubernetes_service_account" "centraldashboard" {
  metadata {
    name      = "centraldashboard"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = local.labels_centraldashboard
  }
}

resource "kubernetes_role" "centraldashboard" {
  metadata {
    name      = "centraldashboard"
    namespace = "kubeflow"

    labels = merge(
      local.labels_argo,
      { app = "centraldashboard" }
    )
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["", "app.k8s.io"]
    resources  = ["applications", "pods", "pods/exec", "pods/log"]
  }

  rule {
    verbs      = ["get"]
    api_groups = [""]
    resources  = ["secrets"]
  }
}

resource "kubernetes_cluster_role" "centraldashboard" {
  metadata {
    name = "centraldashboard"

    labels = merge(
      local.labels_argo,
      { app = "centraldashboard" }
    )
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["events", "namespaces", "nodes"]
  }
}

resource "kubernetes_role_binding" "centraldashboard" {
  metadata {
    name      = "centraldashboard"
    namespace = "kubeflow"

    labels = merge(
      local.labels_argo,
      { app = "centraldashboard" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "centraldashboard"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "centraldashboard"
  }
}

resource "kubernetes_cluster_role_binding" "centraldashboard" {
  metadata {
    name = "centraldashboard"

    labels = merge(
      local.labels_argo,
      { app = "centraldashboard" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "centraldashboard"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "centraldashboard"
  }
}

resource "kubernetes_config_map" "parameters" {
  metadata {
    name      = "parameters"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = local.labels_centraldashboard
  }

  data = {
    clusterDomain = "cluster.local"
  }
}

resource "kubernetes_service" "centraldashboard" {
  metadata {
    name      = "centraldashboard"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_argo,
      { app = "centraldashboard" }
    )

    annotations = {
      "getambassador.io/config" = "---\napiVersion: ambassador/v0\nkind:  Mapping\nname: centralui-mapping\nprefix: /\nrewrite: /\nservice: centraldashboard.kubeflow"
    }
  }

  spec {
    port {
      protocol    = "TCP"
      port        = 80
      target_port = "8082"
    }

    selector = merge(
      local.labels_argo,
      { app = "centraldashboard" }
    )

    type             = "ClusterIP"
    session_affinity = "None"
  }
}

resource "kubernetes_deployment" "centraldashboard" {
  metadata {
    name      = "centraldashboard"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_argo,
      { app = "centraldashboard" }
    )
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        local.labels_argo,
        { app = "centraldashboard" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_argo,
          { app = "centraldashboard" }
        )
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "centraldashboard"
          image = "gcr.io/kubeflow-images-public/centraldashboard:v1.0.0-g3ec0de71"

          port {
            container_port = 8082
            protocol       = "TCP"
          }

          env {
            name = "USERID_HEADER"
          }

          env {
            name = "USERID_PREFIX"
          }

          env {
            name  = "PROFILES_KFAM_SERVICE_HOST"
            value = "profiles-kfam.kubeflow"
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = "8082"
            }

            initial_delay_seconds = 30
            period_seconds        = 30
          }

          image_pull_policy = "IfNotPresent"
        }

        service_account_name = "centraldashboard"
      }
    }
  }
}

locals {
  centraldashboard_application_vs_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/centraldashboard-application-vs.yaml",
    {
      credential_name  = var.certificate_name,
      domain_name      = var.domain_name,
      istio_namespace  = var.istio_namespace
      labels           = local.labels_centraldashboard,
      namespace        = kubernetes_namespace.kubeflow.metadata.0.name
      namespace        = kubernetes_namespace.kubeflow.metadata.0.name,
      use_cert_manager = var.use_cert_manager
    }
    )
  )
}

resource "k8s_manifest" "centraldashboard_application_vs" {
  count      = length(local.centraldashboard_application_vs_manifests)
  depends_on = [k8s_manifest.application_crds]
  content    = local.centraldashboard_application_vs_manifests[count.index]
}


