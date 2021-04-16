terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

resource "kubernetes_secret" "tempest-pushgateway" {
  metadata {
    namespace = var.namespace
    name      = "tempest-pushgateway"
  }

  data = merge(
    tomap({
      "OS_AUTH_TYPE"         = "password"
      "OS_AUTH_URL"          = "http://keystone-api.openstack.svc.cluster.local:5000"
      "OS_USER_DOMAIN_ID"    = "default"
      "OS_PROJECT_DOMAIN_ID" = "default"
      "TEMPEST_PROMETHEUS"   = "prometheus-pushgateway:9091"
      "TEMPEST_HORIZON_URL"  = "http://horizon.openstack.svc.cluster.local"
    }),
    var.env,
  )
}


resource "kubernetes_cron_job" "tempest-pushgateway" {
  metadata {
    namespace = var.namespace
    name      = "tempest-pushgateway"
  }

  spec {
    concurrency_policy            = "Replace"
    schedule                      = var.schedule
    starting_deadline_seconds     = 1800
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 1

    job_template {
      metadata {}

      spec {
        backoff_limit = 0

        template {
          metadata {
            labels = {
              "app" = "tempest-pushgateway"
            }
          }

          spec {
            restart_policy = "Never"
            node_selector  = var.node_selector

            init_container {
              name  = "purge-virtual-machines"
              image = "osclient/python-openstackclient:latest"
              command = [
                "/bin/bash",
                "-xc",
                "openstack server list --project ${var.env.OS_PROJECT_NAME} --name tempest -c ID -f value | xargs openstack server delete --wait"
              ]
            }

            init_container {
              name  = "purge-volumes"
              image = "osclient/python-openstackclient:latest"
              command = [
                "/bin/bash",
                "-xc",
                "openstack volume list --project ${var.env.OS_PROJECT_NAME} --name tempest -c ID -f value | xargs openstack volume delete"
              ]
            }

            init_container {
              name  = "purge-security-groups"
              image = "osclient/python-openstackclient:latest"
              command = [
                "/bin/bash",
                "-xc",
                "openstack security group list --project ${var.env.OS_PROJECT_NAME} -c ID -f value | xargs openstack security group delete"
              ]
            }

            container {
              name  = "tempest-pushgateway"
              image = "vexxhost/tempest-pushgateway:latest"
              args  = var.tests
              env_from {
                secret_ref {
                  name = kubernetes_secret.tempest-pushgateway.metadata[0].name
                }
              }
            }
          }
        }
      }
    }
  }
}
