job "autoscaler-ha-prod4" {

  region      = "de-west"
  datacenters = ["prod4"]
  namespace   = "autoscalerprod4"

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
NOMAD_TOKEN={{ with nomadVar "nomad/jobs/autoscaler-ha-prod4" }}{{ .token }}{{ end }}
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
         data = <<EOH
{{ with nomadVar "nomad/jobs/autoscaler-ha-prod4" }}{{ .cacert }}{{ end }}
         EOH
         destination = "local/nomad-autoscaler/etc/certificates/ca.pem"
      }

      template {
         data = <<EOH
{{ with nomadVar "nomad/jobs/autoscaler-ha-prod4" }}{{ .clientcert }}{{ end }}
         EOH
         destination = "local/nomad-autoscaler/etc/certificates/cert.pem"
      }

      template {
         data = <<EOH
{{ with nomadVar "nomad/jobs/autoscaler-ha-prod4" }}{{ .clientkey }}{{ end }}
         EOH
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
    auth_url    = {{- with nomadVar "nomad/jobs/autoscaler-ha-prod4" }} "{{ .osauthurl }}" {{- end }}
    username    = {{- with nomadVar "nomad/jobs/autoscaler-ha-prod4" }} "{{ .osusername }}" {{- end }}
    password    = {{- with nomadVar "nomad/jobs/autoscaler-ha-prod4" }} "{{ .ospassword }}" {{- end }}
    domain_name = {{- with nomadVar "nomad/jobs/autoscaler-ha-prod4" }} "{{ .osdomainname }}" {{- end }}
    project_id  = {{- with nomadVar "nomad/jobs/autoscaler-ha-prod4" }} "{{ .osprojectid }}" {{- end }}
    region_name = {{- with nomadVar "nomad/jobs/autoscaler-ha-prod4" }} "{{ .osregion }}" {{- end }}
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
      network_id         = "275b130d-c650-4f20-a25c-1f6568f520dc"
      security_groups    = "default"
      availability_zones = "az1"
      tags               = "nom-pool,ubuntu-minimal"
      server_group_id    = "4711168e-fd6b-4092-8470-79f86cfc84f9"
      
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

    }
  }
}
