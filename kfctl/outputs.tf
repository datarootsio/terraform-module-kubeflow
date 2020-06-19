output "wait_for_crds" {
  value = [null_resource.wait_crds, kubernetes_namespace.kfctl_namespace.metadata.0.name]
}