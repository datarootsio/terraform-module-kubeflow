locals {
  labels_persistence_agent = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "persistent-agent"
      "app.kubernetes.io/name"      = "persistent-agent"
      "app.kubernetes.io/instance"  = "persistent-agent-0.2.5"
      "app.kubernetes.io/version"   = "0.2.5"
    }
  )
}

resource "kubernetes_service_account" "ml_pipeline_persistenceagent" {
  metadata {
    name      = "ml-pipeline-persistenceagent"
    namespace = "kubeflow"
    labels = merge(
      local.labels_persistence_agent,
      { app = "ml-pipeline-persistenceagent" }
    )
  }
}

resource "kubernetes_cluster_role" "ml_pipeline_persistenceagent" {
  metadata {
    name = "ml-pipeline-persistenceagent"
    labels = merge(
      local.labels_persistence_agent,
      { app = "ml-pipeline-persistenceagent" }
    )
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["argoproj.io"]
    resources  = ["workflows"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["kubeflow.org"]
    resources  = ["scheduledworkflows"]
  }
}

resource "kubernetes_cluster_role_binding" "ml_pipeline_persistenceagent" {
  metadata {
    name = "ml-pipeline-persistenceagent"
    labels = merge(
      local.labels_persistence_agent,
      { app = "ml-pipeline-persistenceagent" }
    )
  }

  subject {
    kind      = "ServiceAccount"
    name      = "ml-pipeline-persistenceagent"
    namespace = "kubeflow"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
}

resource "kubernetes_deployment" "ml_pipeline_persistenceagent" {
  depends_on = [k8s_manifest.persistent_agent_application]
  metadata {
    name      = "ml-pipeline-persistenceagent"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = merge(
      local.labels_persistence_agent,
      { app = "ml-pipeline-persistenceagent" }
    )
  }

  spec {
    selector {
      match_labels = merge(
        local.labels_persistence_agent,
        { app = "ml-pipeline-persistenceagent" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.labels_persistence_agent,
          { app = "ml-pipeline-persistenceagent" }
        )
      }

      spec {
        automount_service_account_token = true
        container {
          name  = "ml-pipeline-persistenceagent"
          image = "gcr.io/ml-pipeline/persistenceagent:0.2.5"

          env {
            name = "POD_NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          image_pull_policy = "IfNotPresent"
        }

        service_account_name = "ml-pipeline-persistenceagent"
      }
    }
  }
}

locals {
  persistent_agent_application_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/persistent-agent-application-crd.yaml",
    {
      namespace = kubernetes_namespace.kubeflow.metadata.0.name,
      labels    = local.labels_persistence_agent,
    }
    )
  )
}

resource "k8s_manifest" "persistent_agent_application" {
  count      = length(local.persistent_agent_application_manifests)
  depends_on = [k8s_manifest.application_crds]
  content    = local.persistent_agent_application_manifests[count.index]
}