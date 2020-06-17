locals {
  labels_pipelines_ui = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "pipelines-ui"
      "app.kubernetes.io/name"      = "pipelines-ui"
      "app.kubernetes.io/instance"  = "pipelines-ui-0.2.5"
      "app.kubernetes.io/version"   = "0.2.5"
    }
  )
}

resource "kubernetes_service_account" "ml_pipeline_ui" {
  metadata {
    name      = "ml-pipeline-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_pipelines_ui
  }
}

resource "kubernetes_role" "ml_pipeline_ui" {
  metadata {
    name      = "ml-pipeline-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_pipelines_ui,
      { app = "ml-pipeline-ui" }
    )
  }

  rule {
    verbs      = ["create", "get", "list"]
    api_groups = [""]
    resources  = ["pods", "pods/log"]
  }

  rule {
    verbs      = ["create", "get", "list", "watch", "delete"]
    api_groups = ["kubeflow.org"]
    resources  = ["viewers"]
  }
}

resource "kubernetes_role_binding" "ml_pipeline_ui" {
  metadata {
    name      = "ml-pipeline-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_pipelines_ui,
      { app = "ml-pipeline-viewer-crd" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "ml-pipeline-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "ml-pipeline-ui"
  }
}

resource "kubernetes_config_map" "ui_parameters_hb_792_fcf_5_d" {
  metadata {
    name      = "ui-parameters-hb792fcf5d"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_pipelines_ui
  }

  data = {
    uiClusterDomain = "cluster.local"
  }
}

resource "kubernetes_service" "ml_pipeline_tensorboard_ui" {
  metadata {
    name      = "ml-pipeline-tensorboard-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_pipelines_ui,
      { app = "ml-pipeline-tensorboard-ui" }
    )

    annotations = {
      "getambassador.io/config" = "---\napiVersion: ambassador/v0\nkind:  Mapping\nname: pipeline-tensorboard-ui-mapping\nprefix: /data\nrewrite: /data\ntimeout_ms: 300000\nservice: ml-pipeline-ui.kubeflow\nuse_websocket: true"
    }
  }

  spec {
    port {
      port        = 80
      target_port = "3000"
    }

    selector = merge(
      local.labels_pipelines_ui,
      { app = "ml-pipeline-tensorboard-ui" }
    )
  }
}

resource "kubernetes_service" "ml_pipeline_ui" {
  metadata {
    name      = "ml-pipeline-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_pipelines_ui,
      { app = "ml-pipeline-ui" }
    )

    annotations = {
      "getambassador.io/config" = "---\napiVersion: ambassador/v0\nkind:  Mapping\nname: pipelineui-mapping\nprefix: /pipeline\nrewrite: /pipeline\ntimeout_ms: 300000\nservice: ml-pipeline-ui.kubeflow\nuse_websocket: true"
    }
  }

  spec {
    port {
      port        = 80
      target_port = "3000"
    }

    selector = merge(
      local.labels_pipelines_ui,
      { app = "ml-pipeline-ui" }
    )
  }
}

resource "kubernetes_deployment" "ml_pipeline_ui" {
  depends_on = [k8s_manifest.pipelines_ui_application_vs]
  metadata {
    name      = "ml-pipeline-ui"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_pipelines_ui,
      { app = "ml-pipeline-ui" }
    )
  }

  spec {
    selector {
      match_labels = merge(
        local.labels_pipelines_ui,
        { app = "ml-pipeline-ui" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_pipelines_ui,
          { app = "ml-pipeline-ui" }
        )
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "ml-pipeline-ui"
          image = "gcr.io/ml-pipeline/frontend:0.2.5"

          port {
            container_port = 3000
          }

          env {
            name  = "ALLOW_CUSTOM_VISUALIZATIONS"
            value = "true"
          }

          image_pull_policy = "IfNotPresent"
        }

        service_account_name = "ml-pipeline-ui"
      }
    }
  }
}

locals {
  pipelines_ui_application_vs_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/pipelines-ui-application-vs.yaml",
    {
      labels      = local.labels_pipelines_ui,
      domain_name = var.domain_name,
      namespace   = kubernetes_namespace.kubeflow.metadata.0.name
    }
    )
  )
}

resource "k8s_manifest" "pipelines_ui_application_vs" {
  count      = length(local.pipelines_ui_application_vs_manifests)
  depends_on = [k8s_manifest.application_crds, var.kubeflow_depends_on]
  content    = local.pipelines_ui_application_vs_manifests[count.index]
}