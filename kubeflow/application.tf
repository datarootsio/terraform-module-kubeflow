locals {
  labels_application = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "kubeflow"
      "app.kubernetes.io/name"      = "kubeflow"
      "app.kubernetes.io/instance"  = "kubeflow-v1.0.0"
      "app.kubernetes.io/version"   = "v1.0.0"
    }
  )
}

resource "k8s_manifest" "application_crds" {
  content = templatefile(
    "${path.module}/manifests/application-crds.yaml", {}
  )
}

resource "kubernetes_service_account" "application_controller_service_account" {
  metadata {
    name      = "application-controller-service-account"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_application
  }
}

resource "kubernetes_cluster_role" "application_controller_cluster_role" {
  metadata {
    name   = "application-controller-cluster-role"
    labels = local.labels_application
  }

  rule {
    verbs      = ["get", "list", "update", "patch", "watch"]
    api_groups = ["*"]
    resources  = ["*"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["app.k8s.io"]
    resources  = ["*"]
  }
}

resource "kubernetes_cluster_role_binding" "application_controller_cluster_role_binding" {
  metadata {
    name   = "application-controller-cluster-role-binding"
    labels = local.labels_application
  }

  subject {
    kind      = "ServiceAccount"
    name      = "application-controller-service-account"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "application-controller-cluster-role"
  }
}

resource "kubernetes_config_map" "application_controller_parameters" {
  metadata {
    name      = "application-controller-parameters"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_application
  }
}

resource "kubernetes_service" "application_controller_service" {
  metadata {
    name      = "application-controller-service"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_application
  }

  spec {
    port {
      port = 443
    }

    selector = local.labels_application
  }
}

resource "kubernetes_stateful_set" "application_controller_stateful_set" {
  metadata {
    name      = "application-controller-stateful-set"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_application
  }

  spec {
    selector {
      match_labels = merge(
        local.labels_application,
        {
          "app" = "application-controller"
        }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_application,
          {
            "app" = "application-controller"
          }
        )
        annotations = {
          "sidecar.istio.io/inject" = "false"
        }
      }

      spec {
        automount_service_account_token = true

        container {
          name    = "manager"
          image   = "gcr.io/kubeflow-images-public/kubernetes-sigs/application:1.0-beta"
          command = ["/root/manager"]

          env {
            name = "project"
          }

          image_pull_policy = "Always"
        }

        service_account_name = "application-controller-service-account"
      }
    }

    service_name = "application-controller-service"
  }
}

resource "k8s_manifest" "application_application" {
  depends_on = [k8s_manifest.application_crds]

  content = templatefile(
    "${path.module}/manifests/application-application.yaml",
    {
      namespace = kubernetes_namespace.kubeflow.metadata.0.name,
      labels    = local.labels_application
    }
  )
}
