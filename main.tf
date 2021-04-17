terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
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
      "OS_AUTH_URL"          = "http://keystone-api.openstack.svc.cluster.local:5000/v3"
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
              name              = "purge-virtual-machines"
              image             = "osclient/python-openstackclient:latest"
              image_pull_policy = "IfNotPresent"
              command           = [
                "/bin/bash",
                "-xc",
                "openstack server list --name tempest -c ID -f value | xargs -r openstack server delete --wait"
              ]

              env_from {
                secret_ref {
                  name = kubernetes_secret.tempest-pushgateway.metadata[0].name
                }
              }
            }

            init_container {
              name              = "purge-key-pairs"
              image             = "osclient/python-openstackclient:latest"
              image_pull_policy = "IfNotPresent"
              command           = [
                "/bin/bash",
                "-xc",
                "openstack keypair list -c Name -f value | xargs -r openstack keypair delete"
              ]

              env_from {
                secret_ref {
                  name = kubernetes_secret.tempest-pushgateway.metadata[0].name
                }
              }
            }

            init_container {
              name              = "purge-volumes"
              image             = "osclient/python-openstackclient:latest"
              image_pull_policy = "IfNotPresent"
              command           = [
                "/bin/bash",
                "-xc",
                "openstack volume list --name tempest -c ID -f value | xargs -r openstack volume delete"
              ]

              env_from {
                secret_ref {
                  name = kubernetes_secret.tempest-pushgateway.metadata[0].name
                }
              }
            }

            init_container {
              name              = "purge-security-groups"
              image             = "osclient/python-openstackclient:latest"
              image_pull_policy = "IfNotPresent"
              command           = [
                "/bin/bash",
                "-xc",
                "openstack security group list -c ID -c Name -f value | grep -v default | cut -d' ' -f1 | xargs -r openstack security group delete"
              ]

              env_from {
                secret_ref {
                  name = kubernetes_secret.tempest-pushgateway.metadata[0].name
                }
              }
            }

            container {
              name              = "tempest-pushgateway"
              image             = "vexxhost/tempest-pushgateway:latest"
              image_pull_policy = "IfNotPresent"
              args              = var.tests

              env_from {
                secret_ref {
                  name = kubernetes_secret.tempest-pushgateway.metadata[0].name
                }
              }
            }

            dynamic "host_aliases" {
              for_each = var.host_aliases

              content {
                hostnames = [host_aliases.key]
                ip        = host_aliases.value
              }
            }
          }
        }
      }
    }
  }
}

resource "kubectl_manifest" "prometheus-rules" {
    yaml_body = <<YAML
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  namespace: ${var.namespace}
  name: tempest-pushgateway
spec:
  groups:
  - name: tempest
    rules:
    - alert: TempestTestNotRunning
      expr: |
        time() - tempest_last_run_unixtime > 900
      labels:
        severity: P3
      annotations:
        summary: "[`{{`{{$labels.instance}}`}}`] Tempest not reporting"
        description: >
          Tempest has not reported in for over 15 minutes which means that the
          tests are not running and the state of the cloud is unknown.
    - alert: TempestTestFailure
      expr: |
        tempest_last_run_result{tempest_last_run_result="success"} != 1
      labels:
        severity: P5
      annotations:
        summary: "[`{{`{{$labels.instance}}`}}`] Tempest test failure"
        description: >
          The test `{{`{{$labels.instance}}`}}` has failed in it's most recent
          run.
    - alert: TempestTestFailure
      for: 8m
      expr: |
        tempest_last_run_result{tempest_last_run_result="success"} != 1
      labels:
        severity: P4
      annotations:
        summary: "[`{{`{{$labels.instance}}`}}`] Tempest test failure"
        description: >
          The test `{{`{{$labels.instance}}`}}` has failed in it's most recent
          run for 8 minutes.
    - alert: TempestTestFailure
      for: 13m
      expr: |
        tempest_last_run_result{tempest_last_run_result="success"} != 1
      labels:
        severity: P3
      annotations:
        summary: "[`{{`{{$labels.instance}}`}}`] Tempest test failure"
        description: >
          The test `{{`{{$labels.instance}}`}}` has failed in it's most recent
          run for 13 minutes.
YAML
}