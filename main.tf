provider "kubernetes" {}

provider "k8s" {}

provider "helm" {}

terraform {
  required_version = "~> 0.12"
}
