locals {
  labels_argo = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "argo"
      "app.kubernetes.io/name"      = "argo"
      "app.kubernetes.io/instance"  = "argo-v2.3.0"
      "app.kubernetes.io/version"   = "v2.3.0"
    }
  )
}

resource "kubernetes_service_account" "argo_ui" {
  metadata {
    name      = "argo-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = local.labels_argo
  }
}

resource "kubernetes_service_account" "argo" {
  metadata {
    name      = "argo"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = local.labels_argo

  }
}

resource "kubernetes_cluster_role" "argo_ui" {
  metadata {
    name = "argo-ui"

    labels = merge(
      local.labels_argo,
      { app = "argo" }
    )
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["pods", "pods/exec", "pods/log"]
  }

  rule {
    verbs      = ["get"]
    api_groups = [""]
    resources  = ["secrets"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["argoproj.io"]
    resources  = ["workflows", "workflows/finalizers"]
  }
}

resource "kubernetes_cluster_role" "argo" {
  metadata {
    name = "argo"

    labels = merge(
      local.labels_argo,
      { app = "argo" }
    )
  }

  rule {
    verbs      = ["create", "get", "list", "watch", "update", "patch"]
    api_groups = [""]
    resources  = ["pods", "pods/exec"]
  }

  rule {
    verbs      = ["get", "watch", "list"]
    api_groups = [""]
    resources  = ["configmaps"]
  }

  rule {
    verbs      = ["create", "delete"]
    api_groups = [""]
    resources  = ["persistentvolumeclaims"]
  }

  rule {
    verbs      = ["get", "list", "watch", "update", "patch"]
    api_groups = ["argoproj.io"]
    resources  = ["workflows", "workflows/finalizers"]
  }
}

resource "kubernetes_cluster_role_binding" "argo_ui" {
  metadata {
    name = "argo-ui"

    labels = local.labels_argo
  }

  subject {
    kind      = "ServiceAccount"
    name      = "argo-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "argo-ui"
  }
}

resource "kubernetes_cluster_role_binding" "argo" {
  metadata {
    name = "argo"

    labels = merge(
      local.labels_argo,
      { app = "argo" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "argo"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "argo"
  }
}

resource "kubernetes_config_map" "workflow_controller_configmap" {
  metadata {
    name      = "workflow-controller-configmap"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = local.labels_argo
  }

  data = {
    "config" = templatefile("${path.module}/configs/argo.json",
      {
        minio_secret = kubernetes_secret.mlpipeline_minio_artifact.metadata.0.name,
        namespace    = kubernetes_namespace.kubeflow.metadata.0.name
      }
    )
  }
}

resource "kubernetes_config_map" "workflow_controller_parameters" {
  metadata {
    name      = "workflow-controller-parameters"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = local.labels_argo
  }

  data = {
    artifactRepositoryAccessKeySecretKey  = "accesskey"
    artifactRepositoryAccessKeySecretName = kubernetes_secret.mlpipeline_minio_artifact.metadata.0.name
    artifactRepositoryBucket              = "mlpipeline"
    artifactRepositoryEndpoint            = "minio-service.kubeflow:9000"
    artifactRepositoryInsecure            = "true"
    artifactRepositoryKeyPrefix           = "artifacts"
    artifactRepositorySecretKeySecretKey  = "secretkey"
    artifactRepositorySecretKeySecretName = kubernetes_secret.mlpipeline_minio_artifact.metadata.0.name
    clusterDomain                         = "cluster.local"
    containerRuntimeExecutor              = "docker"
    executorImage                         = "argoproj/argoexec:v2.3.0"
    namespace                             = kubernetes_namespace.kubeflow.metadata.0.name
  }
}

resource "kubernetes_service" "argo_ui" {
  metadata {
    name      = "argo-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_argo,
      { app = "argo-ui" }
    )

    annotations = {
      "getambassador.io/config" = "---\napiVersion: ambassador/v0\nkind:  Mapping\nname: argo-ui-mapping\nprefix: /argo/\nservice: argo-ui.kubeflow"
    }
  }

  spec {
    port {
      port        = 80
      target_port = "8001"
    }

    selector = merge(
      local.labels_argo,
      { app = "argo-ui" }
    )

    type             = "NodePort"
    session_affinity = "None"
  }
}

resource "kubernetes_deployment" "argo_ui" {
  metadata {
    name      = "argo-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_argo,
      { app = "argo-ui" }
    )
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        local.labels_argo,
        { app = "argo-ui" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_argo,
          { app = "argo-ui" }
        )

        annotations = {
          "sidecar.istio.io/inject" = "false"
        }
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "argo-ui"
          image = "argoproj/argoui:v2.3.0"

          env {
            name = "ARGO_NAMESPACE"

            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "metadata.namespace"
              }
            }
          }

          env {
            name  = "IN_CLUSTER"
            value = "true"
          }

          env {
            name  = "ENABLE_WEB_CONSOLE"
            value = "false"
          }

          env {
            name  = "BASE_HREF"
            value = "/argo/"
          }

          readiness_probe {
            http_get {
              path = "/"
              port = "8001"
            }
          }

          termination_message_path = "/dev/termination-log"
          image_pull_policy        = "IfNotPresent"
        }

        restart_policy                   = "Always"
        termination_grace_period_seconds = 30
        dns_policy                       = "ClusterFirst"
        service_account_name             = "argo-ui"
      }
    }

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_unavailable = "25%"
        max_surge       = "25%"
      }
    }

    revision_history_limit    = 10
    progress_deadline_seconds = 600
  }
}

resource "kubernetes_deployment" "workflow_controller" {
  metadata {
    name      = "workflow-controller"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_argo,
      { app = "worfklow-controller" }
    )
  }

  spec {
    replicas = 1
    selector {
      match_labels = merge(
        local.labels_argo,
        { app = "worfklow-controller" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_argo,
          { app = "worfklow-controller" }
        )

        annotations = {
          "sidecar.istio.io/inject" = "false"
        }
      }

      spec {
        automount_service_account_token = true
        container {
          name    = "workflow-controller"
          image   = "argoproj/workflow-controller:v2.3.0"
          command = ["workflow-controller"]
          args    = ["--configmap", kubernetes_config_map.workflow_controller_configmap.metadata.0.name]

          env {
            name = "ARGO_NAMESPACE"

            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "metadata.namespace"
              }
            }
          }

          termination_message_path = "/dev/termination-log"
          image_pull_policy        = "IfNotPresent"
        }

        restart_policy                   = "Always"
        termination_grace_period_seconds = 30
        dns_policy                       = "ClusterFirst"
        service_account_name             = "argo"
      }
    }

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_unavailable = "25%"
        max_surge       = "25%"
      }
    }

    revision_history_limit    = 10
    progress_deadline_seconds = 600
  }
}

resource "k8s_manifest" "argo_crd_application_virtualservice" {
  depends_on = [k8s_manifest.application_crds]

  content = templatefile(
    "${path.module}/manifests/argo-crd-application-virtualservice.yaml",
    {
      namespace = kubernetes_namespace.kubeflow.metadata.0.name,
      labels    = local.labels_api_service
    }
  )
}

