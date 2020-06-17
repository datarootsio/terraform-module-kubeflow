locals {
  labels_pipeline_visualization_service = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "pipeline-visualization-service"
      "app.kubernetes.io/name"      = "pipeline-visualization-service"
      "app.kubernetes.io/instance"  = "pipeline-visualization-service-0.2.5"
      "app.kubernetes.io/version"   = "0.2.5"
    }
  )
}

resource "kubernetes_service" "ml_pipeline_ml_pipeline_visualizationserver" {
  metadata {
    name      = "ml-pipeline-ml-pipeline-visualizationserver"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_pipeline_visualization_service,
      { app = "ml-pipeline-visualizationserver" }
    )
  }

  spec {
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 8888
      target_port = "8888"
    }

    selector = merge(
      local.labels_pipeline_visualization_service,
      { app = "ml-pipeline-visualizationserver" }
    )
  }
}

resource "kubernetes_deployment" "ml_pipeline_ml_pipeline_visualizationserver" {
  timeouts {
    create = "20 minutes"
  }
  depends_on = [k8s_manifest.pipeline_visualization_service_application]
  metadata {
    name      = "ml-pipeline-ml-pipeline-visualizationserver"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name

    labels = merge(
      local.labels_pipeline_visualization_service,
      { app = "ml-pipeline-visualizationserver" }
    )
  }

  spec {
    selector {
      match_labels = merge(
        local.labels_pipeline_visualization_service,
        { app = "ml-pipeline-visualizationserver" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_pipeline_visualization_service,
          { app = "ml-pipeline-visualizationserver" }
        )
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "ml-pipeline-visualizationserver"
          image = "gcr.io/ml-pipeline/visualization-server:0.2.5"

          port {
            container_port = 8888
          }

          image_pull_policy = "IfNotPresent"
        }
      }
    }
  }
}

locals {
  pipeline_visualization_service_application_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/pipeline-visualization-service-application.yaml",
    {
      namespace = kubernetes_namespace.kubeflow.metadata.0.name,
      labels    = local.labels_pipeline_visualization_service,
    }
    )
  )
}

resource "k8s_manifest" "pipeline_visualization_service_application" {
  count      = length(local.pipeline_visualization_service_application_manifests)
  depends_on = [k8s_manifest.application_crds]
  content    = local.pipeline_visualization_service_application_manifests[count.index]
}