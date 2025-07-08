job "autoscaler-ha-prod1" {

  region      = "de-west"
  datacenters = ["prod1"]
  namespace   = "autoscalerprod1"

  group "autoscaler" {

    network {
      port "http" {}
    }

    task "autoscaler_agent" {
      driver = "exec"
      config {
            command = "/usr/local/bin/nomad-autoscaler"
            args = [
              "agent",
              "-plugin-dir=local/nomad-autoscaler/plugins",
              "-config=local/nomad-autoscaler/etc",
              "-policy-dir=local/nomad-autoscaler/etc/policies",
              #"-nomad-address=https://${attr.unique.network.ip-address}:4646",
              "-nomad-address=https://127.0.0.1:4646",
              "-http-bind-address=${NOMAD_IP_http}",
              "-http-bind-port=${NOMAD_PORT_http}",
              "-nomad-ca-cert=local/nomad-autoscaler/etc/certificates/ca.pem",
              "-nomad-client-cert=local/nomad-autoscaler/etc/certificates/cert.pem",
              "-nomad-client-key=local/nomad-autoscaler/etc/certificates/private_key.pem",
              "-nomad-region=de-west"
            ]
          }
      
      template {
        destination = "${NOMAD_SECRETS_DIR}/env.txt"
        env         = true
        data        = <<EOT
NOMAD_TOKEN={{ with nomadVar "nomad/jobs/autoscaler-ha-prod1" }}{{ .token }}{{ end }}
EOT
      }

      artifact {
        source = "https://github.com/jorgemarey/nomad-nova-autoscaler/releases/download/v0.6.0/nomad-nova-autoscaler-v0.6.0-linux-amd64.tar.gz"
        destination = "local/nomad-autoscaler/plugins"
        options {
            checksum = "md5:fec29af8625842b154d30be8b8db305f"
        }
      }

      template {
         data = <<EOT
{{ with nomadVar "nomad/jobs/autoscaler-ha-prod1" }}{{ .cacert }}{{ end }}
         EOT
         destination = "local/nomad-autoscaler/etc/certificates/ca.pem"
      }

      template {
         data = <<EOT
{{ with nomadVar "nomad/jobs/autoscaler-ha-prod1" }}{{ .clientcert }}{{ end }}
         EOT
         destination = "local/nomad-autoscaler/etc/certificates/cert.pem"
      }

      template {
         data = <<EOT
{{ with nomadVar "nomad/jobs/autoscaler-ha-prod1" }}{{ .clientkey }}{{ end }}
         EOT
         destination = "local/nomad-autoscaler/etc/certificates/private_key.pem"
      }

      template {
         data = <<EOH
#high_availability {
#  enabled        = true
#  lock_namespace = "autoscaler"
#  lock_path      = "ha/lock"
#  lock_ttl       = "30s"
#  lock_delay     = "15s"
#}

apm "nomad-apm" {
  driver = "nomad-apm"
}

target "os-nova" {
  driver = "os-nova"
  config = {
    auth_url    = "https://prod1.api.pco.get-cloud.io:5000/v3"
    username    = "u500884-servergroupadm"
    password    = "heequekeefo/+o0ThohHeK3e"
    domain_name = "d500884"
    project_id  = "37c692d590564a4ebf77a1b9a5c95006"
    region_name = "prod1"
  }
}

strategy "target-value" {
  driver = "target-value"
}
         EOH
         destination = "local/nomad-autoscaler/etc/nomad-autoscaler.hcl"
      }

      template {
         data = <<EOH

scaling "worker_pool_policy" {
  enabled = true
  min     = 1
  max     = 2

  policy {
    cooldown            = "2m"
    evaluation_interval = "1m"

    check "cpu_allocated_percentage" {
      source = "nomad-apm"
      query  = "percentage-allocated_cpu"
      strategy "target-value" {
        target = 70
      }
    }

    target "os-nova" {
      dry-run = false

      stop_first         = true
      image_id           = "3ad266c4-cb0d-47c6-8e2b-9a2124cc4ff5"
      flavor_name        = "SCS-2V-2-20"
      pool_name          = "nom-pool"
      name_prefix        = "nom-"
      network_id         = "b0f7b38f-53e5-4731-9271-bcecd8542e7e"
      security_groups    = "default"
      availability_zones = "az1"
      tags               = "nom-pool,ubuntu-minimal"
      server_group_id    = "25dbf206-7101-4e68-a8ce-5fd8e4d4450f"
      
      node_class                    = "nom-pool"
      node_drain_deadline           = "1h"
      node_drain_ignore_system_jobs = false
      node_purge                    = true
      node_selector_strategy        = "least_busy"
    }
  }
}

         EOH
         destination = "local/nomad-autoscaler/etc/policies/scaling-policy.hcl"
      }

      resources {
        cpu    = 50
        memory = 128
      }

      service {
        name = "nomad-autoscaler"
        port = "http"
        provider = "nomad"
        tags = ["${node.datacenter}"]

        check {
          type     = "http"
          path     = "/v1/health"
          interval = "3s"
          timeout  = "1s"
        }
      }
    }
  }
}
