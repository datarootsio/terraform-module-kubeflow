locals {
  oidc_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "kubeflow"
    "app.kubernetes.io/component"  = "api-service"
    "app.kubernetes.io/name"       = "api-service"
    "app.kubernetes.io/instance"   = "api-service-0.2.5"
    "app.kubernetes.io/version"    = "0.2.5"
  }
}

resource "kubernetes_secret" "oidc_authservice_parameters" {
  metadata {
    name      = "oidc-authservice-parameters"
    namespace = var.istio_namespace

    labels = local.oidc_labels
  }

  data = {
    application_secret = var.application_secret
    client_id          = var.client_id
    namespace          = var.istio_namespace
    oidc_auth_url      = "/dex/auth"
    oidc_provider      = var.issuer
    oidc_redirect_uri  = var.oidc_redirect_uri
    skip_auth_uri      = "/dex"
    userid-header      = "kubeflow-userid"
    userid-prefix      = ""
    userid-claim       = "openid profile email"
    oidc_scopes        = "profile email groups"
  }
}

resource "kubernetes_service" "authservice" {
  metadata {
    name      = "authservice"
    namespace = var.istio_namespace

    labels = local.oidc_labels
  }

  spec {
    port {
      name        = "http-authservice"
      port        = 8080
      target_port = "http-api"
    }

    selector = merge(
      local.oidc_labels, { app = "authservice" }
    )

    type                        = "ClusterIP"
    publish_not_ready_addresses = true
  }
}

resource "kubernetes_stateful_set" "authservice" {
  metadata {
    name      = "authservice"
    namespace = var.istio_namespace

    labels = local.oidc_labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = merge(
        local.oidc_labels, { app = "authservice" }
      )
    }

    template {
      metadata {
        labels = merge(
          local.oidc_labels, { app = "authservice" }
        )

        annotations = {
          "sidecar.istio.io/inject" = "false"
        }
      }

      spec {
        automount_service_account_token = true
        volume {
          name = "data"

          persistent_volume_claim {
            claim_name = "authservice-pvc"
          }
        }

        container {
          name  = "authservice"
          image = "gcr.io/arrikto/kubeflow/oidc-authservice:28c59ef"

          port {
            name           = "http-api"
            container_port = 8080
          }

          env {
            name = "USERID_HEADER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.dex.metadata.0.name
                key  = "userid-header"
              }
            }
          }

          env {
            name = "USERID_PREFIX"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.dex.metadata.0.name
                key  = "userid-prefix"
              }
            }
          }

          env {
            name = "USERID_CLAIM"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.dex.metadata.0.name
                key  = "userid-claim"
              }
            }
          }

          env {
            name = "OIDC_PROVIDER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.dex.metadata.0.name
                key  = "oidc_provider"
              }
            }
          }

          env {
            name = "OIDC_AUTH_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.dex.metadata.0.name
                key  = "oidc_auth_url"
              }
            }
          }

          env {
            name = "OIDC_SCOPES"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.dex.metadata.0.name
                key  = "oidc_scopes"
              }
            }
          }

          env {
            name = "REDIRECT_URI"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.dex.metadata.0.name
                key  = "oidc_redirect_uri"
              }
            }
          }

          env {
            name = "SKIP_AUTH_URI"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.dex.metadata.0.name
                key  = "skip_auth_uri"
              }
            }
          }

          env {
            name  = "PORT"
            value = "8080"
          }

          env {
            name = "CLIENT_ID"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.dex.metadata.0.name
                key  = "client_id"
              }
            }
          }

          env {
            name = "CLIENT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.dex.metadata.0.name
                key  = "application_secret"
              }
            }
          }

          env {
            name  = "STORE_PATH"
            value = "/var/lib/authservice/data.db"
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/authservice"
          }

          readiness_probe {
            http_get {
              path = "/"
              port = "8081"
            }
          }

          image_pull_policy = "Always"
        }

        security_context {
          fs_group = 111
        }
      }
    }

    volume_claim_template {
      metadata {
        labels = merge(
          local.oidc_labels, { app = "authservice" }
        )
      }

      spec {
        access_modes = ["ReadWriteOnce"]

        resources {
          requests = {
            storage = "10Gi"
          }
        }
      }
    }

    service_name = "authservice"
  }
}

locals {
  oidc_authservice_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/oidc-authservice.yaml",
    {
      istio_namespace = var.istio_namespace
      labels          = local.oidc_labels
    }
    )
  )
}

resource "k8s_manifest" "oidc_authservice" {
  depends_on = [var.auth_depends_on]
  count   = length(local.oidc_authservice_manifests)
  content = local.oidc_authservice_manifests[count.index]
}