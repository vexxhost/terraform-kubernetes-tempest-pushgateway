variable "namespace" {
  type        = string
  description = "Namespace for deploying cron job"
}

variable "schedule" {
  type        = string
  description = "Schedule for cron job"
  default     = "*/5 * * * *"
}

variable "env" {
  type        = map(any)
  sensitive   = true
  description = "OpenStack environment variables for project used for testing"
}

variable "tests" {
  type        = list(string)
  description = "List of Tempest tests to run agains the cloud"
  default = [
    "tempest.api.compute.servers.test_create_server.ServersTestBootFromVolume.test_verify_server_details",
    "heat_tempest_plugin.tests.functional.test_resources_list.ResourcesList.test_required_by",
    "tempest_horizon.tests.scenario.test_dashboard_basic_ops.TestDashboardBasicOps"
  ]
}

variable "node_selector" {
  type        = map(any)
  description = "Node selector for cron jobs"
  default     = {}
}