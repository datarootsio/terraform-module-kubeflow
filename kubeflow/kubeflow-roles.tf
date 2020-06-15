locals {
  kubeflow_roles_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/kubeflow-roles.yaml", {}
    )
  )
}

resource "k8s_manifest" "kubeflow_roles" {
  count      = length(local.kubeflow_roles_manifests)
  content    = local.kubeflow_roles_manifests[count.index]
}

