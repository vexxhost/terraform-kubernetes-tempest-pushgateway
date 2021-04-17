terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-kind"
}

provider "kubectl" {
  config_path    = "~/.kube/config"
  config_context = "kind-kind"
}

# NOTE(mnaser): This simualates Prometheus operator CRDs installed
resource "kubectl_manifest" "prometheusrule-crd" {
    yaml_body = <<YAML
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  annotations:
    controller-gen.kubebuilder.io/version: v0.4.1
  creationTimestamp: null
  name: prometheusrules.monitoring.coreos.com
spec:
  group: monitoring.coreos.com
  names:
    kind: PrometheusRule
    listKind: PrometheusRuleList
    plural: prometheusrules
    singular: prometheusrule
  scope: Namespaced
  versions:
  - name: v1
    schema:
      openAPIV3Schema:
        description: PrometheusRule defines recording and alerting rules for a Prometheus instance
        properties:
          apiVersion:
            description: 'APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources'
            type: string
          kind:
            description: 'Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds'
            type: string
          metadata:
            type: object
          spec:
            description: Specification of desired alerting rule definitions for Prometheus.
            properties:
              groups:
                description: Content of Prometheus rule file
                items:
                  description: 'RuleGroup is a list of sequentially evaluated recording and alerting rules. Note: PartialResponseStrategy is only used by ThanosRuler and will be ignored by Prometheus instances.  Valid values for this field are ''warn'' or ''abort''.  More info: https://github.com/thanos-io/thanos/blob/master/docs/components/rule.md#partial-response'
                  properties:
                    interval:
                      type: string
                    name:
                      type: string
                    partial_response_strategy:
                      type: string
                    rules:
                      items:
                        description: Rule describes an alerting or recording rule.
                        properties:
                          alert:
                            type: string
                          annotations:
                            additionalProperties:
                              type: string
                            type: object
                          expr:
                            anyOf:
                            - type: integer
                            - type: string
                            x-kubernetes-int-or-string: true
                          for:
                            type: string
                          labels:
                            additionalProperties:
                              type: string
                            type: object
                          record:
                            type: string
                        required:
                        - expr
                        type: object
                      type: array
                  required:
                  - name
                  - rules
                  type: object
                type: array
            type: object
        required:
        - spec
        type: object
    served: true
    storage: true
status:
  acceptedNames:
    kind: ""
    plural: ""
  conditions: []
  storedVersions: []
YAML
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