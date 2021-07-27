locals {
  kubernetes_resources_labels = merge({
    "cookielab.io/terraform-module" = "datadog",
  }, var.kubernetes_resources_labels)
  daemonset_selector_labels = {
    "cookielab.io/application" = "metrics-server",
    "cookielab.io/process" = "bootstrap"
  }

  daemonset_labels = merge(
    {
      "cookielab.io/terraform-module" = "datadog",
    },
    var.kubernetes_resources_labels,
    {
      "cookielab.io/application" = "metrics-server",
      "cookielab.io/process" = "bootstrap"
    }
  )
}

resource "kubernetes_namespace" "datadog" {
  count = var.kubernetes_namespace_create ? 1 : 0

  metadata {
    name = var.kubernetes_namespace
  }
}

resource "kubernetes_service_account" "datadog_agent" {
  metadata {
    name = "${var.kubernetes_resources_name_prefix}datadog-agent"
    namespace = var.kubernetes_namespace
    labels = local.kubernetes_resources_labels
  }
}

resource "kubernetes_cluster_role" "datadog_agent" {
  metadata {
    name = "${var.kubernetes_resources_name_prefix}datadog-agent"
    labels = local.kubernetes_resources_labels
  }

  rule {
    api_groups = [""]
    resources = [
      "services",
      "events",
      "endpoints",
      "pods",
      "nodes",
      "componentstatuses"
    ]
    verbs = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["quota.openshift.io"]
    resources = ["clusterresourcequotas"]
    verbs = ["get", "list"]
  }

  rule {
    api_groups = [""]
    resources = ["configmaps"]
    resource_names = ["datadogtoken", "datadog-leader-election"]
    verbs = ["get", "update"]
  }

  rule {
    api_groups = [""]
    resources = ["configmaps"]
    verbs = ["create"]
  }

  rule {
    non_resource_urls = [
      "/version",
      "/healthz",
      "/metrics"
    ]
    verbs = ["get"]
  }

  rule {
    api_groups = [""]
    resources = [
      "nodes/metrics",
      "nodes/spec",
      "nodes/proxy",
      "nodes/stats",
    ]
    verbs = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "datadog_agent" {
  metadata {
    name = kubernetes_cluster_role.datadog_agent.metadata.0.name
    labels = kubernetes_cluster_role.datadog_agent.metadata.0.labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = kubernetes_cluster_role.datadog_agent.metadata.0.name
  }

  subject {
    kind = "ServiceAccount"
    namespace = kubernetes_service_account.datadog_agent.metadata.0.namespace
    name = kubernetes_service_account.datadog_agent.metadata.0.name
  }
}

resource "kubernetes_secret" "datadog_agent" {
  metadata {
    name = "${var.kubernetes_resources_name_prefix}datadog-secret"
    namespace = var.kubernetes_namespace
    labels = local.daemonset_labels
  }

  data = {
    "api-key" = var.datadog_agent_api_key
  }
}

resource "kubernetes_daemonset" "datadog_agent" {
  metadata {
    name = "${var.kubernetes_resources_name_prefix}datadog-agent"
    namespace = var.kubernetes_namespace
    labels = local.daemonset_labels
  }

  spec {
    selector {
      match_labels = local.daemonset_selector_labels
    }

    template {
      metadata {
        name = "datadog-agent"
        labels = local.daemonset_labels
      }

      spec {
        service_account_name = kubernetes_service_account.datadog_agent.metadata.0.name
        automount_service_account_token = true

        container {
          image = "${var.datadog_agent_image}:${var.datadog_agent_image_tag}"
          image_pull_policy = "Always"
          name = "datadog-agent"

          port {
            container_port = 8125
            name = "dogstatsdport"
            protocol = "UDP"
          }

          port {
            container_port = 8126
            name = "traceport"
            protocol = "TCP"
          }

          env {
            name = "DD_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.datadog_agent.metadata.0.name
                key = "api-key"
              }
            }
          }

          env {
            name = "DD_SITE"
            value = var.datadog_agent_site
          }

          env {
            name = "KUBERNETES"
            value = "true"
          }

          env {
            name = "DD_DOGSTATSD_NON_LOCAL_TRAFFIC"
            value = "false"
          }

          env {
            name = "DD_HEALTH_PORT"
            value = "5555"
          }

          env {
            name = "DD_COLLECT_KUBERNETES_EVENTS"
            value = var.datadog_agent_options_collect_kubernetes_events
          }

          env {
            name = "DD_LEADER_ELECTION"
            value = "true"
          }

          env {
            name = "DD_APM_ENABLED"
            value = var.datadog_agent_options_apm_enabled
          }
          env {
            name = "DD_LOGS_ENABLED"
            value = var.datadog_agent_options_logs_enabled
          }

          env {
            name = "DD_CLUSTER_NAME"
            value = var.kubernetes_cluster_name
          }

          env {
            name = "DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL"
            value = var.datadog_agent_options_logs_enabled
          }


          env {
            name = "DD_KUBERNETES_KUBELET_HOST"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env {
            name = "DD_ENV"
            value_from {
              field_ref {
                field_path = "metadata.labels['tags.datadoghq.com/env']"
              }
            }
          }

          env {
            name = "DD_KUBELET_TLS_VERIFY"
            value = var.datadog_agent_options_kubelet_tls_verify
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu = "200m"
            }

            limits = {
              memory = "256Mi"
              cpu = "200m"
            }
          }

          volume_mount {
            name = "dockersocket"
            mount_path = "/var/run/docker.sock"
          }

          volume_mount {
            name = "procdir"
            mount_path = "/host/proc"
            read_only = true
          }

          volume_mount {
            name = "cgroups"
            mount_path = "/host/sys/fs/cgroup"
            read_only = true
          }

          volume_mount {
            name = "s6-run"
            mount_path = "/var/run/s6"
          }

          volume_mount {
            name = "logpodpath"
            mount_path = "/var/log/pods"
          }

          volume_mount {
            name = "logcontainerpath"
            mount_path = "/var/lib/docker/containers"
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 5555
            }

            initial_delay_seconds = 15
            period_seconds = 15
            timeout_seconds = 5
            success_threshold = 1
            failure_threshold = 3
          }
        }

        volume {
          name = "dockersocket"
          host_path {
            path = "/var/run/docker.sock"
          }
        }

        volume {
          name = "procdir"
          host_path {
            path = "/proc"
          }
        }

        volume {
          name = "cgroups"
          host_path {
            path = "/sys/fs/cgroup"
          }
        }

        volume {
          name = "s6-run"
          empty_dir {

          }
        }

        volume {
          name = "logpodpath"
          host_path {
            path = "/var/log/pods"
          }
        }

        volume {
          name = "logcontainerpath"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }

        toleration {
          key = "node-role.kubernetes.io/master"
          effect = "NoSchedule"
        }
      }
    }
  }
}