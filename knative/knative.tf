resource "kubernetes_namespace" "knative_operator" {
  metadata {
    name = "knative-operator"
  }
}

resource "kubernetes_namespace" "knative_serving" {
  metadata {
    name = "knative-serving"
    labels = {
      "istio-injection"             = "enabled"
      "serving.knative.dev/release" = "v0.15.0"
    }
  }
}

resource "kubernetes_config_map" "config_logging" {
  metadata {
    name      = "config-logging"
    namespace = kubernetes_namespace.knative_operator.metadata.0.name

    labels = {
      "operator.knative.dev/release" = "devel"
    }
  }

  data = {
    _example = templatefile("${path.module}/configs/logging.yaml", {})
  }
}

resource "kubernetes_config_map" "config_observability" {
  metadata {
    name      = "config-observability"
    namespace = kubernetes_namespace.knative_operator.metadata.0.name

    labels = {
      "operator.knative.dev/release" = "devel"
    }
  }

  data = {
    _example = templatefile("${path.module}/configs/observability.yaml", {})
  }
}

resource "kubernetes_deployment" "knative_operator" {
  depends_on = [var.knative_depends_on, k8s_manifest.knative_crds]
  metadata {
    name      = "knative-operator"
    namespace = kubernetes_namespace.knative_operator.metadata.0.name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "knative-operator"
      }
    }

    template {
      metadata {
        labels = {
          name = "knative-operator"
        }

        annotations = {
          "sidecar.istio.io/inject" = "false"
        }
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "knative-operator"
          image = "gcr.io/knative-releases/knative.dev/operator/cmd/operator@sha256:e94d8d1c739205b5d5929e5cd49f1e1d4007a76e1aae0a6988ce15f21341819e"

          port {
            name           = "metrics"
            container_port = 9090
          }

          env {
            name = "POD_NAME"

            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "SYSTEM_NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          env {
            name  = "METRICS_DOMAIN"
            value = "knative.dev/operator"
          }

          env {
            name  = "CONFIG_LOGGING_NAME"
            value = "config-logging"
          }

          env {
            name  = "CONFIG_OBSERVABILITY_NAME"
            value = "config-observability"
          }

          image_pull_policy = "IfNotPresent"
        }

        service_account_name = kubernetes_service_account.knative_operator.metadata.0.name
      }
    }
  }
}

resource "kubernetes_cluster_role" "knative_operator_operator" {
  metadata {
    name = "knative-serving-operator"
  }

  rule {
    verbs      = ["*"]
    api_groups = ["operator.knative.dev"]
    resources  = ["*"]
  }

  rule {
    verbs          = ["bind", "get"]
    api_groups     = ["rbac.authorization.k8s.io"]
    resources      = ["clusterroles"]
    resource_names = ["system:auth-delegator"]
  }

  rule {
    verbs          = ["bind", "get"]
    api_groups     = ["rbac.authorization.k8s.io"]
    resources      = ["roles"]
    resource_names = ["extension-apiserver-authentication-reader"]
  }

  rule {
    verbs      = ["create", "delete", "escalate", "get", "list", "update"]
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["clusterroles", "roles"]
  }

  rule {
    verbs      = ["create", "delete", "list", "get", "update"]
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["clusterrolebindings", "rolebindings"]
  }

  rule {
    verbs      = ["update"]
    api_groups = ["apiregistration.k8s.io"]
    resources  = ["apiservices"]
  }

  rule {
    verbs      = ["create", "delete", "get", "list", "watch"]
    api_groups = [""]
    resources  = ["services"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["caching.internal.knative.dev"]
    resources  = ["images"]
  }

  rule {
    verbs      = ["get", "update", "watch"]
    api_groups = [""]
    resources  = ["namespaces"]
  }

  rule {
    verbs      = ["create", "update", "patch"]
    api_groups = [""]
    resources  = ["events"]
  }

  rule {
    verbs      = ["create", "delete", "get", "list", "watch"]
    api_groups = [""]
    resources  = ["configmaps"]
  }

  rule {
    verbs      = ["create", "delete", "get", "list", "watch"]
    api_groups = ["apps"]
    resources  = ["deployments", "daemonsets", "replicasets", "statefulsets"]
  }

  rule {
    verbs      = ["create", "delete", "get", "list"]
    api_groups = ["apiregistration.k8s.io"]
    resources  = ["apiservices"]
  }

  rule {
    verbs      = ["create", "delete", "get", "list"]
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
  }

  rule {
    verbs          = ["delete"]
    api_groups     = [""]
    resources      = ["services", "deployments", "horizontalpodautoscalers"]
    resource_names = ["knative-ingressgateway"]
  }

  rule {
    verbs          = ["delete"]
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["config-controller"]
  }

  rule {
    verbs          = ["delete"]
    api_groups     = [""]
    resources      = ["serviceaccounts"]
    resource_names = ["knative-serving-operator"]
  }
}

resource "kubernetes_cluster_role" "knative_eventing_operator" {
  metadata {
    name = "knative-eventing-operator"
  }

  rule {
    verbs      = ["*"]
    api_groups = ["operator.knative.dev"]
    resources  = ["*"]
  }

  rule {
    verbs      = ["create", "delete", "escalate", "get", "list", "update"]
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["clusterroles", "roles"]
  }

  rule {
    verbs      = ["create", "delete", "list", "get", "update"]
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["clusterrolebindings", "rolebindings"]
  }

  rule {
    verbs      = ["update"]
    api_groups = ["apiregistration.k8s.io"]
    resources  = ["apiservices"]
  }

  rule {
    verbs      = ["create", "delete", "get", "list", "watch"]
    api_groups = [""]
    resources  = ["services"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["caching.internal.knative.dev"]
    resources  = ["images"]
  }

  rule {
    verbs      = ["get", "update", "watch"]
    api_groups = [""]
    resources  = ["namespaces"]
  }

  rule {
    verbs      = ["create", "update", "patch"]
    api_groups = [""]
    resources  = ["events"]
  }

  rule {
    verbs      = ["create", "delete", "get", "list", "watch"]
    api_groups = [""]
    resources  = ["configmaps"]
  }

  rule {
    verbs      = ["create", "delete", "get", "list", "watch"]
    api_groups = ["apps"]
    resources  = ["deployments", "daemonsets", "replicasets", "statefulsets"]
  }

  rule {
    verbs      = ["create", "delete", "get", "list"]
    api_groups = ["apiregistration.k8s.io"]
    resources  = ["apiservices"]
  }

  rule {
    verbs      = ["create", "delete", "update", "get", "list"]
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
  }

  rule {
    verbs      = ["*"]
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
  }

  rule {
    verbs      = ["create", "delete", "update", "get", "list", "watch"]
    api_groups = ["batch"]
    resources  = ["jobs"]
  }

  rule {
    verbs          = ["delete"]
    api_groups     = [""]
    resources      = ["serviceaccounts"]
    resource_names = ["knative-eventing-operator"]
  }
}

resource "kubernetes_cluster_role_binding" "knative_operator_operator" {
  metadata {
    name = "knative-serving-operator"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "knative-operator"
    namespace = kubernetes_namespace.knative_operator.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "knative-serving-operator"
  }
}

resource "kubernetes_cluster_role_binding" "knative_operator_operator_aggregated" {
  metadata {
    name = "knative-serving-operator-aggregated"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "knative-operator"
    namespace = kubernetes_namespace.knative_operator.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "knative-serving-operator-aggregated"
  }
}

resource "kubernetes_cluster_role_binding" "knative_eventing_operator" {
  metadata {
    name = "knative-eventing-operator"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "knative-operator"
    namespace = kubernetes_namespace.knative_operator.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "knative-eventing-operator"
  }
}

resource "kubernetes_cluster_role_binding" "knative_eventing_operator_aggregated" {
  metadata {
    name = "knative-eventing-operator-aggregated"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "knative-operator"
    namespace = kubernetes_namespace.knative_operator.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "knative-eventing-operator-aggregated"
  }
}

resource "kubernetes_service_account" "knative_operator" {
  depends_on = [
    kubernetes_cluster_role.knative_eventing_operator,
    kubernetes_cluster_role.knative_operator_operator,
    kubernetes_cluster_role_binding.knative_eventing_operator,
    kubernetes_cluster_role_binding.knative_eventing_operator_aggregated,
    kubernetes_cluster_role_binding.knative_operator_operator,
    kubernetes_cluster_role_binding.knative_operator_operator_aggregated
  ]
  metadata {
    name      = "knative-operator"
    namespace = kubernetes_namespace.knative_operator.metadata.0.name
  }
}

locals {
  knative_crds = split("\n---\n", templatefile(
    "${path.module}/manifests/knative-crds.yaml", {}
    )
  )
}

resource "k8s_manifest" "knative_crds" {
  count      = length(local.knative_crds)
  depends_on = [var.knative_depends_on]
  content    = local.knative_crds[count.index]
}

resource "k8s_manifest" "knative_operator" {
  depends_on = [var.knative_depends_on, kubernetes_deployment.knative_operator, k8s_manifest.knative_crds]
  content = templatefile(
    "${path.module}/manifests/knative-operator.yaml",
    { namespace = kubernetes_namespace.knative_serving.metadata.0.name }
  )
}