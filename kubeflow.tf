module "kubeflow" {
  providers = {
    kubernetes = kubernetes
    k8s        = k8s
  }
  source = "./kubeflow"
}
