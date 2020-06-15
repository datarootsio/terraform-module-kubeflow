provider "k8s" {}

provider "kubernetes" {}

resource "kubernetes_namespace" "istio_namespace" {
  metadata {
    name = var.istio_namespace

    labels = {
      istio-injection = "disabled"

      istio-operator-managed = "Reconcile"
    }
  }
}

resource "k8s_manifest" "istio_deployment" {
  depends_on = [kubernetes_deployment.istio_operator, k8s_manifest.operator_crd, kubernetes_cluster_role_binding.istio_operator]
  content = templatefile(
    "${path.module}/manifests/istio-deployment.yaml",
    {
      namespace   = kubernetes_namespace.istio_namespace.metadata.0.name,
      annotations = var.ingress_gateway_annotations,
      lb_ip       = var.ingress_gateway_ip
    }
  )
}

resource "null_resource" "wait_crds" {
  depends_on = [k8s_manifest.istio_deployment]

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash","-c"]
    command = "while [[ \"$(kubectl get crds | grep 'istio.io' | wc -l)\" -ne \"25\" ]]; do echo \"Waiting for CRDs\";  sleep 5; done"
  }
}

locals {
  kiali = split(
    "\n---\n", templatefile("${path.module}/manifests/kiali.yaml",
      {
        credential_name  = var.certificate_name,
        domain_name      = var.domain_name,
        namespace        = var.istio_namespace,
        use_cert_manager = var.use_cert_manager
      }
    )
  )
}

resource "k8s_manifest" "kiali_manifests" {
  depends_on = [var.istio_depends_on, k8s_manifest.operator_crd, kubernetes_deployment.istio_operator, kubernetes_cluster_role_binding.istio_operator, null_resource.wait_crds]
  count      = length(local.kiali)
  content    = local.kiali[count.index]
}