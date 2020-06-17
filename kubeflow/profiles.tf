locals {
  labels_profiles = merge(
    local.common_labels,
    {
      "app.kubernetes.io/component" = "profiles"
      "app.kubernetes.io/name"      = "profiles"
      "app.kubernetes.io/instance"  = "profiles-v1.0.0"
      "app.kubernetes.io/version"   = "v1.0.0"
    }
  )
}

resource "kubernetes_service_account" "profiles_controller_service_account" {
  metadata {
    name      = "profiles-controller-service-account"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_profiles
  }
}

resource "kubernetes_cluster_role_binding" "profiles_cluster_role_binding" {
  metadata {
    name   = "profiles-cluster-role-binding"
    labels = local.labels_profiles
  }

  subject {
    kind      = "ServiceAccount"
    name      = "profiles-controller-service-account"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
}

resource "kubernetes_config_map" "profiles_profiles_parameters_78m_7_mmbb_5_c" {
  metadata {
    name      = "profiles-profiles-parameters-78m7mmbb5c"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_profiles
  }

  data = {
    admin         = "anonymous"
    userid-header = "kubeflow-userid"
  }
}

resource "kubernetes_service" "profiles_kfam" {
  metadata {
    name      = "profiles-kfam"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels    = local.labels_profiles
  }

  spec {
    port {
      port = 8081
    }
    selector = local.labels_profiles
  }
}

resource "kubernetes_deployment" "profiles_deployment" {
  depends_on = [k8s_manifest.profiles_application_crd_vs]
  metadata {
    name      = "profiles-deployment"
    namespace = kubernetes_namespace.kubeflow.metadata.0.name
    labels = local.labels_profiles
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.labels_profiles
    }

    template {
      metadata {
    labels = local.labels_profiles
      }

      spec {
        automount_service_account_token = true
        container {
          name    = "manager"
          image   = "gcr.io/kubeflow-images-public/profile-controller:v1.0.0-ge50a8531"
          command = ["/manager"]
          args    = ["-userid-header", "kubeflow-userid", "-userid-prefix", "", "-workload-identity", ""]

          liveness_probe {
            http_get {
              path = "/metrics"
              port = "8080"
            }

            initial_delay_seconds = 30
            period_seconds        = 30
          }

          image_pull_policy = "Always"
        }

        container {
          name    = "kfam"
          image   = "gcr.io/kubeflow-images-public/kfam:v1.0.0-gf3e09203"
          command = ["/access-management"]
          args    = ["-cluster-admin", "anonymous", "-userid-header", "kubeflow-userid", "-userid-prefix", ""]

          liveness_probe {
            http_get {
              path = "/metrics"
              port = "8081"
            }

            initial_delay_seconds = 30
            period_seconds        = 30
          }

          image_pull_policy = "Always"
        }

        service_account_name = "profiles-controller-service-account"
      }
    }
  }
}

locals {
  profiles_application_crd_vs_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/profiles-application-crd-vs.yaml",
    {
      labels      = local.labels_profiles,
      domain_name = var.domain_name,
      namespace   = kubernetes_namespace.kubeflow.metadata.0.name
    }
    )
  )
}

resource "k8s_manifest" "profiles_application_crd_vs" {
  count      = length(local.profiles_application_crd_vs_manifests)
  depends_on = [k8s_manifest.application_crds, var.kubeflow_depends_on]
  content    = local.profiles_application_crd_vs_manifests[count.index]
}