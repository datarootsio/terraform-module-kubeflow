locals {
  labels_kfserving = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "kfserving"
      "app.kubernetes.io/name"      = "kfserving"
      "app.kubernetes.io/instance"  = "kfserving-0.2.2"
      "app.kubernetes.io/version"   = "0.2.2"
    }
  )
}

resource "kubernetes_cluster_role" "kfserving_proxy_role" {
  metadata {
    name   = "kfserving-proxy-role"
    labels = local.labels_kfserving
  }

  rule {
    verbs      = ["create"]
    api_groups = ["authentication.k8s.io"]
    resources  = ["tokenreviews"]
  }

  rule {
    verbs      = ["create"]
    api_groups = ["authorization.k8s.io"]
    resources  = ["subjectaccessreviews"]
  }
}

resource "kubernetes_cluster_role" "kubeflow_kfserving_edit" {
  metadata {
    name = "kubeflow-kfserving-edit"
    labels = merge(
      local.labels_kfserving,
      {
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-edit"            = "true"
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-kfserving-admin" = "true"
      }
    )
  }

  rule {
    verbs      = ["get", "list", "watch", "create", "delete", "deletecollection", "patch", "update"]
    api_groups = ["serving.kubeflow.org"]
    resources  = ["inferenceservices"]
  }
}

resource "kubernetes_cluster_role" "kubeflow_kfserving_view" {
  metadata {
    name = "kubeflow-kfserving-view"
    labels = merge(
      local.labels_kfserving,
      {
        "rbac.authorization.kubeflow.org/aggregate-to-kubeflow-view" = "true"
      }
    )
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["serving.kubeflow.org"]
    resources  = ["inferenceservices"]
  }
}

resource "kubernetes_cluster_role" "manager_role" {
  metadata {
    name   = "manager-role"
    labels = local.labels_kfserving
  }

  rule {
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
    api_groups = ["serving.knative.dev"]
    resources  = ["services"]
  }

  rule {
    verbs      = ["get", "update", "patch"]
    api_groups = ["serving.knative.dev"]
    resources  = ["services/status"]
  }

  rule {
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
    api_groups = ["networking.istio.io"]
    resources  = ["virtualservices"]
  }

  rule {
    verbs      = ["get", "update", "patch"]
    api_groups = ["networking.istio.io"]
    resources  = ["virtualservices/status"]
  }

  rule {
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
    api_groups = ["serving.kubeflow.org"]
    resources  = ["inferenceservices"]
  }

  rule {
    verbs      = ["get", "update", "patch"]
    api_groups = ["serving.kubeflow.org"]
    resources  = ["inferenceservices/status"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["serviceaccounts"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["secrets"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["configmaps"]
  }

  rule {
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
    api_groups = ["admissionregistration.k8s.io"]
    resources  = ["mutatingwebhookconfigurations", "validatingwebhookconfigurations"]
  }

  rule {
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
    api_groups = [""]
    resources  = ["secrets"]
  }

  rule {
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
    api_groups = [""]
    resources  = ["services"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["namespaces"]
  }
}

resource "kubernetes_cluster_role_binding" "kfserving_proxy_rolebinding" {
  metadata {
    name   = "kfserving-proxy-rolebinding"
    labels = local.labels_kfserving
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "kfserving-proxy-role"
  }
}

resource "kubernetes_cluster_role_binding" "manager_rolebinding" {
  metadata {
    name   = "manager-rolebinding"
    labels = local.labels_kfserving
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "manager-role"
  }
}

resource "kubernetes_config_map" "inferenceservice_config" {
  metadata {
    name      = "inferenceservice-config"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_kfserving
  }

  data = {
    credentials        = templatefile("${path.module}/configs/kfserving-credentials.json", {})
    explainers         = templatefile("${path.module}/configs/kfserving-explainers.json", {})
    logger             = templatefile("${path.module}/configs/kfserving-logger.json", {})
    predictors         = templatefile("${path.module}/configs/kfserving-predictors.json", {})
    storageInitializer = templatefile("${path.module}/configs/kfserving-storage-initializer.json", {})
    transformers       = templatefile("${path.module}/configs/kfserving-transformers.json", {})
    ingress = templatefile(
      "${path.module}/configs/kfserving-ingress.json",
      { istio_namespace = var.istio_namespace }
    )
  }
}

resource "kubernetes_config_map" "kfserving_parameters_dbdb_8_cm_9_t2" {
  metadata {
    name      = "kfserving-parameters-dbdb8cm9t2"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_kfserving
  }

  data = {
    registry = "gcr.io/kfserving"
  }
}

resource "kubernetes_secret" "kfserving_webhook_server_secret" {
  metadata {
    name      = "kfserving-webhook-server-secret"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_kfserving
  }
}

resource "kubernetes_service" "kfserving_controller_manager_metrics_service" {
  metadata {
    name      = "kfserving-controller-manager-metrics-service"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_kfserving,
      {
        control-plane             = "controller-manager"
        "controller-tools.k8s.io" = "1.0"
      }
    )

    annotations = {
      "prometheus.io/port"   = "8443"
      "prometheus.io/scheme" = "https"
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      name        = "https"
      port        = 8443
      target_port = "https"
    }

    selector = merge(
      local.labels_kfserving,
      {
        "controller-tools.k8s.io" = "1.0"
        "kustomize.component"     = "kfserving"
      }
    )
  }
}

resource "kubernetes_service" "kfserving_controller_manager_service" {
  metadata {
    name      = "kfserving-controller-manager-service"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_kfserving,
      {
        control-plane             = "kfserving-controller-manager"
        "controller-tools.k8s.io" = "1.0"
      }
    )
  }

  spec {
    port {
      port = 443
    }

    selector = merge(
      local.labels_kfserving,
      {
        control-plane             = "kfserving-controller-manager"
        "controller-tools.k8s.io" = "1.0"
      }
    )
  }
}

resource "kubernetes_stateful_set" "kfserving_controller_manager" {
  depends_on = [k8s_manifest.kfserving_crd_application]
  metadata {
    name      = "kfserving-controller-manager"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_kfserving,
      {
        control-plane             = "kfserving-controller-manager"
        "controller-tools.k8s.io" = "1.0"
      }
    )
  }


  spec {

    update_strategy {
      type = "RollingUpdate"
    }

    selector {
      match_labels = merge(
        local.labels_kfserving,
        {
          control-plane             = "kfserving-controller-manager"
          "controller-tools.k8s.io" = "1.0"
        }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_kfserving,
          {
            control-plane             = "kfserving-controller-manager"
            "controller-tools.k8s.io" = "1.0"
          }
        )

        annotations = {
          "sidecar.istio.io/inject" = "false"
        }
      }

      spec {
        automount_service_account_token = true
        volume {
          name = "cert"

          secret {
            secret_name  = "kfserving-webhook-server-secret"
            default_mode = "0644"
          }
        }

        container {
          name  = "kube-rbac-proxy"
          image = "gcr.io/kubebuilder/kube-rbac-proxy:v0.4.0"
          args  = ["--secure-listen-address=0.0.0.0:8443", "--upstream=http://127.0.0.1:8080/", "--logtostderr=true", "--v=10"]

          port {
            name           = "https"
            container_port = 8443
          }
        }

        container {
          name    = "manager"
          image   = "gcr.io/kfserving/kfserving-controller:0.2.2"
          command = ["/manager"]
          args    = ["--metrics-addr=127.0.0.1:8080"]

          port {
            name           = "webhook-server"
            container_port = 9876
            protocol       = "TCP"
          }

          env {
            name = "POD_NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          env {
            name  = "SECRET_NAME"
            value = "kfserving-webhook-server-secret"
          }

          env {
            name  = "ENABLE_WEBHOOK_NAMESPACE_SELECTOR"
            value = "enabled"
          }

          resources {
            limits {
              cpu    = "100m"
              memory = "300Mi"
            }

            requests {
              cpu    = "100m"
              memory = "200Mi"
            }
          }

          volume_mount {
            name       = "cert"
            read_only  = true
            mount_path = "/tmp/cert"
          }

          image_pull_policy = "Always"
        }

        termination_grace_period_seconds = 10
      }
    }

    service_name = "controller-manager-service"
  }
}

locals {
  kfserving_crd_application_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/kfserving-crd-application.yaml",
    {
      namespace = kubernetes_namespace.kubeflow.metadata.0.name,
      labels    = local.labels_kfserving
    }
    )
  )
}

resource "k8s_manifest" "kfserving_crd_application" {
  count      = length(local.kfserving_crd_application_manifests)
  depends_on = [k8s_manifest.application_crds]
  content    = local.kfserving_crd_application_manifests[count.index]
}