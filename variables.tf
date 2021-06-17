variable "kubernetes_namespace" {
  type = string
  default = "datadog"
  description = "Kubernetes namespace to deploy datadog agent."
}

variable "kubernetes_namespace_create" {
  type = bool
  default = true
  description = "Do you want to create kubernetes namespace?"
}

variable "kubernetes_resources_name_prefix" {
  type = string
  default = ""
  description = "Prefix for kubernetes resources name. For example `tf-module-`"
}

variable "kubernetes_resources_labels" {
  type = map(string)
  default = {}
  description = "Additional labels for kubernetes resources."
}

variable "kubernetes_deployment_node_selector" {
  type = map(string)
  default = {
    "beta.kubernetes.io/os" = "linux"
  }
  description = "Node selectors for kubernetes deployment"
}

variable "datadog_agent_image" {
  type = string
  default = "datadog/agent"
}

variable "datadog_agent_image_tag" {
  type = string
  default = "latest"
}

variable "datadog_agent_api_key" {
  type = string
  description = "Set the Datadog API Key related to your Organization"
}

variable "datadog_agent_site" {
  type = string
  default = "datadoghq.com"
  description = "Set to 'datadoghq.eu' to send your Agent data to the Datadog EU site"
}

variable "datadog_agent_options_kubelet_tls_verify" {
  type = bool
  default = true
  description = "Check Kubelet TLS certs?"
}

variable "datadog_agent_options_apm_enabled" {
  type = bool
  default = true
  description = "Enable APM logging?"
}

variable "datadog_agent_options_logs_enabled" {
  type = bool
  default = true
  description = "Enable datadog logs?"
}

variable "datadog_agent_options_collect_kubernetes_events" {
  type = bool
  default = true
  description = "Collect Kubernetes events?"
}