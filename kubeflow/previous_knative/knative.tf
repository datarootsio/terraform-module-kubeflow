/*locals {
  labels_knative = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "knative-serving"
      "app.kubernetes.io/name"      = "knative-serving"
      "app.kubernetes.io/instance"  = "knative-serving-v0.11.1"
      "app.kubernetes.io/version"   = "v0.11.1"
      "serving.knative.dev/release" = "v0.11.1"
    }
  )
}

resource "kubernetes_namespace" "knative_serving" {
  metadata {
    name = "knative-serving"
    labels = merge(
      local.labels_knative,
      { "istio-injection" = "enabled" }
    )
  }
}



resource "kubernetes_service_account" "controller" {
  metadata {
    name      = "controller"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels    = local.labels_knative
  }
}

resource "kubernetes_cluster_role" "custom_metrics_server_resources" {
  metadata {
    name   = "custom-metrics-server-resources"
    labels = local.labels_knative
  }

  rule {
    verbs      = ["*"]
    api_groups = ["custom.metrics.k8s.io"]
    resources  = ["*"]
  }
}

resource "kubernetes_cluster_role" "knative_serving_addressable_resolver" {
  metadata {
    name   = "knative-serving-addressable-resolver"
    labels = local.labels_knative
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["serving.knative.dev"]
    resources  = ["routes", "routes/status", "services", "services/status"]
  }
}

resource "kubernetes_cluster_role" "knative_serving_core" {
  metadata {
    name   = "knative-serving-core"
    labels = local.labels_knative
  }

  rule {
    verbs      = ["get", "list", "create", "update", "delete", "patch", "watch"]
    api_groups = [""]
    resources  = ["pods", "namespaces", "secrets", "configmaps", "endpoints", "services", "events", "serviceaccounts"]
  }

  rule {
    verbs      = ["create"]
    api_groups = [""]
    resources  = ["endpoints/restricted"]
  }

  rule {
    verbs      = ["get", "list", "create", "update", "delete", "patch", "watch"]
    api_groups = ["apps"]
    resources  = ["deployments", "deployments/finalizers"]
  }

  rule {
    verbs      = ["get", "list", "create", "update", "delete", "patch", "watch"]
    api_groups = ["admissionregistration.k8s.io"]
    resources  = ["mutatingwebhookconfigurations", "validatingwebhookconfigurations"]
  }

  rule {
    verbs      = ["get", "list", "create", "update", "delete", "patch", "watch"]
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
  }

  rule {
    verbs      = ["get", "list", "create", "update", "delete", "patch", "watch"]
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
  }

  rule {
    verbs      = ["get", "list", "create", "update", "delete", "deletecollection", "patch", "watch"]
    api_groups = ["serving.knative.dev", "autoscaling.internal.knative.dev", "networking.internal.knative.dev"]
    resources  = ["*", "*/status", "*/finalizers"]
  }

  rule {
    verbs      = ["get", "list", "create", "update", "delete", "patch", "watch"]
    api_groups = ["caching.internal.knative.dev"]
    resources  = ["images"]
  }
}

resource "kubernetes_cluster_role" "knative_serving_istio" {
  metadata {
    name   = "knative-serving-istio"
    labels = local.labels_knative
  }

  rule {
    verbs      = ["get", "list", "create", "update", "delete", "patch", "watch"]
    api_groups = ["networking.istio.io"]
    resources  = ["virtualservices", "gateways"]
  }
}

resource "kubernetes_cluster_role" "knative_serving_namespaced_admin" {
  metadata {
    name   = "knative-serving-namespaced-admin"
    labels = local.labels_knative
  }

  rule {
    verbs      = ["*"]
    api_groups = ["serving.knative.dev", "networking.internal.knative.dev", "autoscaling.internal.knative.dev", "caching.internal.knative.dev"]
    resources  = ["*"]
  }
}

resource "kubernetes_cluster_role" "knative_serving_namespaced_edit" {
  metadata {
    name   = "knative-serving-namespaced-edit"
    labels = local.labels_knative
  }

  rule {
    verbs      = ["create", "update", "patch", "delete"]
    api_groups = ["serving.knative.dev", "networking.internal.knative.dev", "autoscaling.internal.knative.dev", "caching.internal.knative.dev"]
    resources  = ["*"]
  }
}

resource "kubernetes_cluster_role" "knative_serving_namespaced_view" {
  metadata {
    name   = "knative-serving-namespaced-view"
    labels = local.labels_knative
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["serving.knative.dev", "networking.internal.knative.dev", "autoscaling.internal.knative.dev", "caching.internal.knative.dev"]
    resources  = ["*"]
  }
}

resource "kubernetes_cluster_role" "knative_serving_podspecable_binding" {
  metadata {
    name = "knative-serving-podspecable-binding"
    labels = merge(
      local.labels_knative,
      { "duck.knative.dev/podspecable" = "true" }
    )
  }

  rule {
    verbs      = ["list", "watch", "patch"]
    api_groups = ["serving.knative.dev"]
    resources  = ["configurations", "services"]
  }
}

resource "kubernetes_role_binding" "custom_metrics_auth_reader" {
  depends_on = [kubernetes_api_service.custom_metrics]
  metadata {
    name      = "custom-metrics-auth-reader"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels = merge(
      local.labels_knative,
      { "autoscaling.knative.dev/metric-provider" = "custom-metrics" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "controller"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "extension-apiserver-authentication-reader"
  }
}

resource "kubernetes_cluster_role_binding" "custom_metrics_system_auth_delegator" {
  metadata {
    name = "custom-metrics:system:auth-delegator"
    labels = merge(
      local.labels_knative,
      { "autoscaling.knative.dev/metric-provider" = "custom-metrics" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "controller"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
}

resource "kubernetes_cluster_role_binding" "hpa_controller_custom_metrics" {
  metadata {
    name = "hpa-controller-custom-metrics"
    labels = merge(
      local.labels_knative,
      { "autoscaling.knative.dev/metric-provider" = "custom-metrics" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "horizontal-pod-autoscaler"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "custom-metrics-server-resources"
  }
}

resource "kubernetes_cluster_role_binding" "knative_serving_controller_admin" {
  metadata {
    name = "knative-serving-controller-admin"

    labels = local.labels_knative
  }

  subject {
    kind      = "ServiceAccount"
    name      = "controller"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "knative-serving-admin"
  }
}

resource "kubernetes_config_map" "config_autoscaler" {
  metadata {
    name      = "config-autoscaler"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels    = local.labels_knative
  }

  data = {
    _example = templatefile("${path.module}/configs/knative/autoscaler.yaml", {})
  }
}

resource "kubernetes_config_map" "config_defaults" {
  metadata {
    name      = "config-defaults"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels    = local.labels_knative
  }

  data = {
    _example = templatefile("${path.module}/configs/knative/defaults.yaml", {})
  }
}

resource "kubernetes_config_map" "config_deployment" {
  metadata {
    name      = "config-deployment"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels    = local.labels_knative
  }

  data = {
    _example          = templatefile("${path.module}/configs/knative/deployment.yaml", {})
    queueSidecarImage = "gcr.io/knative-releases/knative.dev/serving/cmd/queue@sha256:792f6945c7bc73a49a470a5b955c39c8bd174705743abf5fb71aa0f4c04128eb"
  }
}

resource "kubernetes_config_map" "config_domain" {
  metadata {
    name      = "config-domain"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels    = local.labels_knative
  }

  data = {
    _example = templatefile("${path.module}/configs/knative/domain.yaml", {})
  }
}

resource "kubernetes_config_map" "config_gc" {
  metadata {
    name      = "config-gc"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels    = local.labels_knative
  }

  data = {
    _example = templatefile("${path.module}/configs/knative/gc.yaml", {})
  }
}

resource "kubernetes_config_map" "config_istio" {
  metadata {
    name      = "config-istio"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels    = local.labels_knative
  }

  data = {
    "gateway.knative-serving.knative-ingress-gateway"     = "kfserving-ingressgateway.istio-system.svc.cluster.local"
    "local-gateway.knative-serving.cluster-local-gateway" = "cluster-local-gateway.istio-system.svc.cluster.local"
    "local-gateway.mesh"                                  = "mesh"
    reconcileExternalGateway                              = "false"
  }
}

resource "kubernetes_config_map" "config_logging" {
  metadata {
    name      = "config-logging"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels    = local.labels_knative
  }

  data = {
    _example = templatefile("${path.module}/configs/knative/logging.yaml", {})
  }
}

resource "kubernetes_config_map" "config_network" {
  metadata {
    name      = "config-network"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels    = local.labels_knative
  }

  data = {
    _example = templatefile("${path.module}/configs/knative/network.yaml", {})
  }
}

resource "kubernetes_config_map" "config_observability" {
  metadata {
    name      = "config-observability"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels    = local.labels_knative
  }

  data = {
    _example = templatefile("${path.module}/configs/knative/observability.yaml", {})
  }
}

resource "kubernetes_config_map" "config_tracing" {
  metadata {
    name      = "config-tracing"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels    = local.labels_knative
  }

  data = {
    _example = templatefile("${path.module}/configs/knative/tracing.yaml", {})
  }
}

resource "kubernetes_secret" "webhook_certs" {
  metadata {
    name      = "webhook-certs"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels    = local.labels_knative
  }
}

resource "kubernetes_service" "activator_service" {
  metadata {
    name      = "activator-service"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels = merge(
      { "app" = "activator" },
      local.labels_knative
    )
  }

  spec {
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = "8012"
    }

    port {
      name        = "http2"
      protocol    = "TCP"
      port        = 81
      target_port = "8013"
    }

    port {
      name        = "http-metrics"
      protocol    = "TCP"
      port        = 9090
      target_port = "9090"
    }

    selector = merge(
      { "app" = "activator" },
      local.labels_knative
    )
    type = "ClusterIP"
  }
}

resource "kubernetes_service" "autoscaler" {
  metadata {
    name      = "autoscaler"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name

    labels = merge(
      { "app" = "autoscaler" },
      local.labels_knative
    )
  }

  spec {
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 8080
      target_port = "8080"
    }

    port {
      name        = "http-metrics"
      protocol    = "TCP"
      port        = 9090
      target_port = "9090"
    }

    port {
      name        = "https-custom-metrics"
      protocol    = "TCP"
      port        = 443
      target_port = "8443"
    }

    selector = merge(
      { "app" = "autoscaler" },
      local.labels_knative
    )
  }
}

resource "kubernetes_service" "controller" {
  metadata {
    name      = "controller"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name

    labels = merge(
      { "app" = "controller" },
      local.labels_knative
    )
  }

  spec {
    port {
      name        = "http-metrics"
      protocol    = "TCP"
      port        = 9090
      target_port = "9090"
    }

    selector = merge(
      { "app" = "controller" },
      local.labels_knative
    )
  }
}

resource "kubernetes_service" "webhook" {
  metadata {
    name      = "webhook"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name

    labels = merge(
      { "role" = "webhook" },
      local.labels_knative
    )
  }

  spec {
    port {
      name        = "https-webhook"
      port        = 443
      target_port = "8443"
    }

    selector = merge(
      { "role" = "webhook" },
      local.labels_knative
    )
  }
}

resource "kubernetes_deployment" "activator" {
  depends_on = [k8s_manifest.knative_crds_application_webhooks]
  metadata {
    name      = "activator"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name

    labels = merge(
      { "app" = "activator" },
      local.labels_knative
    )
  }

  spec {
    selector {
      match_labels = merge(
        { "app" = "activator" },
        local.labels_knative
      )
    }

    template {
      metadata {
        labels = merge(
          { "app" = "activator" },
          local.labels_knative
        )

        annotations = {
          "cluster-autoscaler.kubernetes.io/safe-to-evict" = "false"
          "sidecar.istio.io/inject"                        = "true"
        }
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "activator"
          image = "gcr.io/knative-releases/knative.dev/serving/cmd/activator@sha256:8e606671215cc029683e8cd633ec5de9eabeaa6e9a4392ff289883304be1f418"

          port {
            name           = "http1"
            container_port = 8012
          }

          port {
            name           = "h2c"
            container_port = 8013
          }

          port {
            name           = "metrics"
            container_port = 9090
          }

          port {
            name           = "profiling"
            container_port = 8008
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
            name = "POD_IP"

            value_from {
              field_ref {
                field_path = "status.podIP"
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
            name  = "CONFIG_LOGGING_NAME"
            value = "config-logging"
          }

          env {
            name  = "CONFIG_OBSERVABILITY_NAME"
            value = "config-observability"
          }

          env {
            name  = "METRICS_DOMAIN"
            value = "knative.dev/internal/serving"
          }

          resources {
            limits {
              cpu    = "1"
              memory = "600Mi"
            }

            requests {
              cpu    = "300m"
              memory = "60Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = "8012"

              http_header {
                name  = "k-kubelet-probe"
                value = "activator"
              }
            }
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = "8012"

              http_header {
                name  = "k-kubelet-probe"
                value = "activator"
              }
            }
          }
        }

        termination_grace_period_seconds = 300
        service_account_name             = "controller"
      }
    }
  }
}

resource "kubernetes_deployment" "autoscaler_hpa" {
  depends_on = [k8s_manifest.knative_crds_application_webhooks]
  metadata {
    name      = "autoscaler-hpa"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name

    labels = merge(
      { "autoscaling.knative.dev/autoscaler-provider" = "hpa" },
      local.labels_knative
    )
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        { "app" = "autoscaler-hpa" },
        local.labels_knative
      )
    }

    template {
      metadata {
        labels = merge(
          { "app" = "autoscaler-hpa" },
          local.labels_knative
        )

        annotations = {
          "sidecar.istio.io/inject" = "false"
        }
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "autoscaler-hpa"
          image = "gcr.io/knative-releases/knative.dev/serving/cmd/autoscaler-hpa@sha256:5e0fadf574e66fb1c893806b5c5e5f19139cc476ebf1dff9860789fe4ac5f545"

          port {
            name           = "metrics"
            container_port = 9090
          }

          port {
            name           = "profiling"
            container_port = 8008
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
            name  = "CONFIG_LOGGING_NAME"
            value = "config-logging"
          }

          env {
            name  = "CONFIG_OBSERVABILITY_NAME"
            value = "config-observability"
          }

          env {
            name  = "METRICS_DOMAIN"
            value = "knative.dev/serving"
          }

          resources {
            limits {
              cpu    = "1"
              memory = "1000Mi"
            }

            requests {
              memory = "100Mi"
              cpu    = "100m"
            }
          }
        }

        service_account_name = "controller"
      }
    }
  }
}

resource "kubernetes_deployment" "autoscaler" {
  depends_on = [k8s_manifest.knative_crds_application_webhooks]
  metadata {
    name      = "autoscaler"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels    = local.labels_knative
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        { "app" = "autoscaler" },
        local.labels_knative
      )
    }

    template {
      metadata {
        labels = merge(
          { "app" = "autoscaler" },
          local.labels_knative
        )

        annotations = {
          "cluster-autoscaler.kubernetes.io/safe-to-evict" = "false"
          "sidecar.istio.io/inject"                        = "true"
          "traffic.sidecar.istio.io/includeInboundPorts"   = "8080,9090"
        }
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "autoscaler"
          image = "gcr.io/knative-releases/knative.dev/serving/cmd/autoscaler@sha256:ef1f01b5fb3886d4c488a219687aac72d28e72f808691132f658259e4e02bb27"
          args  = ["--secure-port=8443", "--cert-dir=/tmp"]

          port {
            name           = "websocket"
            container_port = 8080
          }

          port {
            name           = "metrics"
            container_port = 9090
          }

          port {
            name           = "custom-metrics"
            container_port = 8443
          }

          port {
            name           = "profiling"
            container_port = 8008
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
            name  = "CONFIG_LOGGING_NAME"
            value = "config-logging"
          }

          env {
            name  = "CONFIG_OBSERVABILITY_NAME"
            value = "config-observability"
          }

          env {
            name  = "METRICS_DOMAIN"
            value = "knative.dev/serving"
          }

          resources {
            limits {
              cpu    = "300m"
              memory = "400Mi"
            }

            requests {
              cpu    = "30m"
              memory = "40Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = "8080"

              http_header {
                name  = "k-kubelet-probe"
                value = "autoscaler"
              }
            }
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = "8080"

              http_header {
                name  = "k-kubelet-probe"
                value = "autoscaler"
              }
            }
          }
        }

        service_account_name = "controller"
      }
    }
  }
}

resource "kubernetes_deployment" "controller" {
  depends_on = [k8s_manifest.knative_crds_application_webhooks]
  metadata {
    name      = "controller"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name

    labels = local.labels_knative
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        { "app" = "controller" },
        local.labels_knative
      )
    }

    template {
      metadata {
        labels = merge(
          { "app" = "controller" },
          local.labels_knative
        )

        annotations = {
          "sidecar.istio.io/inject" = "false"
        }
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "controller"
          image = "gcr.io/knative-releases/knative.dev/serving/cmd/controller@sha256:5ca13e5b3ce5e2819c4567b75c0984650a57272ece44bc1dabf930f9fe1e19a1"

          port {
            name           = "metrics"
            container_port = 9090
          }

          port {
            name           = "profiling"
            container_port = 8008
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
            name  = "CONFIG_LOGGING_NAME"
            value = "config-logging"
          }

          env {
            name  = "CONFIG_OBSERVABILITY_NAME"
            value = "config-observability"
          }

          env {
            name  = "METRICS_DOMAIN"
            value = "knative.dev/internal/serving"
          }

          resources {
            limits {
              cpu    = "1"
              memory = "1000Mi"
            }

            requests {
              cpu    = "100m"
              memory = "100Mi"
            }
          }
        }

        service_account_name = "controller"
      }
    }
  }
}

resource "kubernetes_deployment" "networking_istio" {
  depends_on = [k8s_manifest.knative_crds_application_webhooks]
  metadata {
    name      = "networking-istio"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels = merge(
      { "networking.knative.dev/ingress-provider" = "istio" },
      local.labels_knative
    )
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        { "app" = "networking-istio" },
        local.labels_knative
      )
    }

    template {
      metadata {
        labels = merge(
          { "app" = "networking-istio" },
          local.labels_knative
        )

        annotations = {
          "sidecar.istio.io/inject" = "false"
        }
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "networking-istio"
          image = "gcr.io/knative-releases/knative.dev/serving/cmd/networking/istio@sha256:727a623ccb17676fae8058cb1691207a9658a8d71bc7603d701e23b1a6037e6c"

          port {
            name           = "metrics"
            container_port = 9090
          }

          port {
            name           = "profiling"
            container_port = 8008
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
            name  = "CONFIG_LOGGING_NAME"
            value = "config-logging"
          }

          env {
            name  = "CONFIG_OBSERVABILITY_NAME"
            value = "config-observability"
          }

          env {
            name  = "METRICS_DOMAIN"
            value = "knative.dev/serving"
          }

          resources {
            limits {
              cpu    = "1"
              memory = "1000Mi"
            }

            requests {
              memory = "100Mi"
              cpu    = "100m"
            }
          }
        }

        service_account_name = "controller"
      }
    }
  }
}

resource "kubernetes_deployment" "webhook" {
  depends_on = [k8s_manifest.knative_crds_application_webhooks]
  metadata {
    name      = "webhook"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name
    labels    = local.labels_knative
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        { "app" = "networking-istio", "role" = "webhook" },
        local.labels_knative
      )
    }

    template {
      metadata {
        labels = merge(
          { "app" = "networking-istio", "role" = "webhook" },
          local.labels_knative
        )

        annotations = {
          "cluster-autoscaler.kubernetes.io/safe-to-evict" = "false"
          "sidecar.istio.io/inject"                        = "false"
        }
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "webhook"
          image = "gcr.io/knative-releases/knative.dev/serving/cmd/webhook@sha256:1ef3328282f31704b5802c1136bd117e8598fd9f437df8209ca87366c5ce9fcb"

          port {
            name           = "metrics"
            container_port = 9090
          }

          port {
            name           = "profiling"
            container_port = 8008
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
            name  = "CONFIG_LOGGING_NAME"
            value = "config-logging"
          }

          env {
            name  = "CONFIG_OBSERVABILITY_NAME"
            value = "config-observability"
          }

          env {
            name  = "METRICS_DOMAIN"
            value = "knative.dev/serving"
          }

          resources {
            limits {
              cpu    = "200m"
              memory = "200Mi"
            }

            requests {
              cpu    = "20m"
              memory = "20Mi"
            }
          }
        }

        service_account_name = "controller"
      }
    }
  }
}

resource "kubernetes_api_service" "custom_metrics" {
  metadata {
    name = "v1beta1.custom.metrics.k8s.io"
    labels = merge(
      { "autoscaling.knative.dev/metric-provider" = "custom-metrics" },
      local.labels_knative
    )
  }

  spec {
    service {
      namespace = kubernetes_namespace.knative_serving.metadata.0.name
      name      = "autoscaler"
    }

    group                    = "custom.metrics.k8s.io"
    version                  = "v1beta1"
    insecure_skip_tls_verify = true
    group_priority_minimum   = 100
    version_priority         = 100
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "activator" {
  metadata {
    name      = "activator"
    namespace = kubernetes_namespace.knative_serving.metadata.0.name

    labels = local.labels_knative
  }

  spec {
    scale_target_ref {
      kind        = "Deployment"
      name        = "activator"
      api_version = "apps/v1"
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 100
        }
      }
    }

    min_replicas = 1
    max_replicas = 20
  }
}

locals {
  knative_crds_application_webhooks = split("\n---\n", templatefile(
    "${path.module}/manifests/knative-crds-application-webhooks.yaml",
    {
      labels    = local.labels_knative,
      namespace = kubernetes_namespace.kubeflow.metadata.0.name
    }
    )
  )
}

resource "k8s_manifest" "knative_crds_application_webhooks" {
  count      = length(local.knative_crds_application_webhooks)
  depends_on = [k8s_manifest.application_crds, var.kubeflow_depends_on]
  content    = local.knative_crds_application_webhooks[count.index]
}*/