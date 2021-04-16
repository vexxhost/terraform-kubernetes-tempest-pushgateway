provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-kind"
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

module "tempest-pushgateway" {
    source = "../../"

    namespace = kubernetes_namespace.monitoring.metadata[0].name
    schedule  = "*/1 * * * *"
    env       = {
      "OS_USERNAME":     "tempest",
      "OS_PROJECT_NAME": "tempest",
      "OS_PASSWORD":     "secret",
    }
}