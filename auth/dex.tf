locals {
  application_application_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/application-application.yaml",
    {
      namespace = kubernetes_namespace.auth.metadata.0.name,
    }
    )
  )
}

resource "k8s_manifest" "application_application" {
  count   = length(local.application_application_manifests)
  content = local.application_application_manifests[count.index]
}

resource "kubernetes_service_account" "dex" {
  metadata {
    name      = "dex"
    namespace = kubernetes_namespace.auth.metadata.0.name
  }
}

resource "kubernetes_cluster_role" "dex" {
  metadata {
    name = "dex"
  }

  rule {
    verbs      = ["*"]
    api_groups = ["dex.coreos.com"]
    resources  = ["*"]
  }

  rule {
    verbs      = ["create"]
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
  }
}

resource "kubernetes_cluster_role_binding" "dex" {
  metadata {
    name = "dex"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "dex"
    namespace = kubernetes_namespace.auth.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "dex"
  }
}

resource "kubernetes_config_map" "dex_parameters" {
  metadata {
    name      = "dex-parameters"
    namespace = kubernetes_namespace.auth.metadata.0.name
  }

  data = {
    application_secret   = "pUBnBOY80SnXgjibTYM9ZWNzY2xreNGQok"
    client_id            = "kubeflow-oidc-authservice"
    dex_domain           = "dex.example.com"
    issuer               = "http://dex.auth.svc.cluster.local:5556/dex"
    namespace            = kubernetes_namespace.auth.metadata.0.name
    oidc_redirect_uris   = "[\"/login/oidc\"]"
    static_email         = "admin@kubeflow.org"
    static_password_hash = "$2y$12$ruoM7FqXrpVgaol44eRZW.4HWS8SAvg6KYVVSCIwKQPBmTpCm.EeO"
    static_user_id       = "08a8684b-db88-4b73-90a9-3cd1661f5466"
    static_username      = "admin"
  }
}

resource "kubernetes_secret" "dex" {
  metadata {
    name      = "dex"
    namespace = kubernetes_namespace.auth.metadata.0.name
  }

  data = {
    "config.yaml" = templatefile("${path.module}/configs/dex.yaml", {})
  }
}

resource "kubernetes_service" "dex" {
  metadata {
    name      = "dex"
    namespace = kubernetes_namespace.auth.metadata.0.name
  }

  spec {
    port {
      name        = "dex"
      protocol    = "TCP"
      port        = 5556
      target_port = "5556"
      node_port   = 32000
    }

    selector = {
      app = "dex"
    }

    type = "NodePort"
  }
}

resource "kubernetes_deployment" "dex" {
  metadata {
    name      = "dex"
    namespace = kubernetes_namespace.auth.metadata.0.name

    labels = {
      app = "dex"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "dex"
      }
    }

    template {
      metadata {
        labels = {
          app = "dex"
        }
      }

      spec {
        automount_service_account_token = true
        volume {
          name = "config"

          secret {
            secret_name = "dex"

            items {
              key  = "config.yaml"
              path = "config.yaml"
            }
          }
        }

        container {
          name    = "dex"
          image   = "gcr.io/arrikto/dexidp/dex:4bede5eb80822fc3a7fc9edca0ed2605cd339d17"
          command = ["dex", "serve", "/etc/dex/cfg/config.yaml"]

          port {
            name           = "http"
            container_port = 5556
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/dex/cfg"
          }
        }

        service_account_name = "dex"
      }
    }
  }
}

