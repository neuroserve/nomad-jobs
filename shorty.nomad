job "shorty" { 
   datacenters = ["prod4"]

   group "shorty" {
    #  count = 2
    #  spread {
    #    attribute = "${node.datacenter}"
    #    target "prod1" {
    #      percent = 50
    #    }
    #    target "prod4" {
    #      percent = 50
    #    }
    #  }
      constraint {
        operator = "distinct_hosts"
        value = "true"
      }
      network {
         port "kuttcontainer" { 
           host_network = "local"
         }
         port "rediscontainer" {
           host_network = "local"
         }
    #     port "caddy-http" { static = "8080" }
    #     port "caddy-https" { static = "8443" }
      }

       task "caddy" {
         driver = "exec"
         config {
          command = "/usr/bin/caddy"
          args = [
            "run",
            "--environ",
            "--config",
            "local/Caddyfile",
          ]
         }
         template {
          data = <<EOH
shorty.code667.net {
        {{- range nomadService "shorty" }}
        reverse_proxy {{ .Address }}:{{ .Port }}{{- end}} 

        tls hein@bloed.com
}
EOH
          destination = "local/Caddyfile"
         }
       }

       task "kuttcontainer" {
        env {
          PORT = "${NOMAD_HOST_PORT_kuttcontainer}"
          SITE_NAME = "shorty"
          DEFAULT_DOMAIN = "shorty.code667.net"
          DB_CLIENT = "pg"
          DB_HOST = "primary.patroni42.service.consul"
          DB_PORT = "5432"
          DB_NAME = "shorty"
          DB_USER = "shorty"
          DB_SSL = "false"
          DB_POOL_MIN = "0"
          DB_POOL_MAY = "10"
          LINK_LENGTH = "6"
          LINK_CUSTOM_ALPHABET = "abcdefghkmnpqrstuvwxyzABCDEFGHKLMNPQRSTUVWXYZ23456789"
          TRUST_PROXY = "true"
          REDIS_ENABLED = "false"
          REDIS_HOST = "${NOMAD_IP_rediscontainer}"
          REDIS_PORT = "${NOMAD_HOST_PORT_rediscontainer}"
          REDIS_DB = "0"
          REDIS_PASSWORD = ""
          DISALLOW_REGISTRATION = "true"
          DISALLOW_ANONYMOUS_LINKS = "false"
        } 
        template {
          destination = "${NOMAD_SECRETS_DIR}/env.txt"
          env         = true
          data        = <<EOT
JWT_SECRET  = {{ with nomadVar "nomad/jobs/shorty" }}{{ .jwtsecret }}{{ end }}
DB_PASSWORD = {{ with nomadVar "nomad/jobs/shorty" }}{{ .dbpassword }}{{ end }}
          EOT
        }
        driver = "docker"
          config {              
            image = "kutt/kutt:main"
            ports = [ "kuttcontainer" ]
          }
          service {
             tags = [ "${node.datacenter}"]
             name = "shorty"
             port = "kuttcontainer"
             provider ="nomad"

           check {
              type = "tcp"
              port = "kuttcontainer"
              interval = "10s"
              timeout = "2s"

             check_restart {
                limit = 3
                grace = "90s"
                ignore_warnings = "false"
              }
            }
          }
       }
       
       task "rediscontainer" {
         driver = "docker"
         config {
            image = "redis:7"
            ports = ["rediscontainer"]
          }
          service {
              tags = [ "${node.datacenter}"]
              name = "rediscontainer"
              port = "rediscontainer"
              provider ="nomad"

            check {
               type = "tcp"
               port = "rediscontainer"
               interval = "10s"
               timeout = "2s"

              check_restart {
                 limit = 3
                 grace = "90s"
                 ignore_warnings = "false"
              }
            }
          }
        }
    }
}

#in nomad.hcl
#host_network "overlay" {
#                interface = "nebula0"
#}
#in group block
#network {
#      port "internalservice" {
#        host_network = "overlay"
#        static       = "80"
#        to           = 80
#      }
#}
#and in service block:
#service {
#        name         = "internalservice"
#        port         = "internalservice"
#        provider     = "nomad"
#        address      = "your_nebula0_ip"
#        address_mode = "auto"
#      }
