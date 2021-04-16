variable "namespace" {
  type = string
}

variable "schedule" {
  type    = string
  default = "*/5 * * * *"
}

variable "env" {
  type = map
  sensitive = true
}

variable "tests" {
  type = list(string)
  default = [
    "tempest.api.compute.servers.test_create_server.ServersTestBootFromVolume.test_verify_server_details",
    "heat_tempest_plugin.tests.functional.test_resources_list.ResourcesList.test_required_by",
    "tempest_horizon.tests.scenario.test_dashboard_basic_ops.TestDashboardBasicOps"
  ]
}

variable "node_selector" {
  type    = map
  default = {}
}