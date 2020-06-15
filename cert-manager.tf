resource "kubernetes_namespace" "cert_manager" {
  metadata {
    annotations = {
      name = var.cert_manager_namespace
    }
    name = var.cert_manager_namespace
  }
}

resource "null_resource" "apply_crd" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.14.1/cert-manager.crds.yaml"
  }
}

resource "helm_release" "cert_manager" {
  depends_on    = [null_resource.apply_crd]
  name          = "cert-manager"
  repository    = "https://charts.jetstack.io"
  namespace     = kubernetes_namespace.cert_manager.metadata.0.name
  chart         = "cert-manager"
  keyring       = ""
  recreate_pods = true
  version       = "v0.14.1"
}


resource "k8s_manifest" "selfsigned_issuer" {
  depends_on = [helm_release.cert_manager]
  content = templatefile(
    "${path.module}/manifests/cert-manager/self-signed.yaml",
    {}
  )
}

resource "k8s_manifest" "letsencrypt_issuer" {
  depends_on = [helm_release.cert_manager]
  content = templatefile(
    "${path.module}/manifests/cert-manager/letsencrypt-prod.yaml",
    {
      email = var.letsencrypt_email
    }
  )
}