job "shorty" { 
   datacenters = ["prod4", "prod1"]

   group "shorty" {
      count = 2
    #  spread {
    #    attribute = "${node.datacenter}"
    #    target "prod1" {
    #      percent = 50
    #    }
    #    target "prod4" {
    #      percent = 50
    #    }
    #  }
      network {
         mode = "bridge"
         port "shorty" {
           to           = 3000 
           host_network = "overlay"
         }
         port "redis" {
           to           = 6379
           host_network = "overlay"
         }
      }

       task "shorty" {
        template {
          destination = "env"
          env = true
          data = <<EOT
PORT=3000
SITE_NAME=shorty
DEFAULT_DOMAIN=shorty.app.tgos.xyz
JWT_SECRET={{ with nomadVar "nomad/jobs/shorty" }}{{ .jwtsecret }}{{ end }}
DB_CLIENT=pg
DB_HOST=primary.patroni42.service.consul
DB_PORT=5432
DB_NAME=shorty
DB_USER=shorty
DB_PASSWORD={{ with nomadVar "nomad/jobs/shorty" }}{{ .dbpassword }}{{ end }}
DB_SSL=false
DB_POOL_MIN=0
DB_POOL_MAX=10
LINK_LENGTH=6
LINK_CUSTOM_ALPHABET=abcdefghkmnpqrstuvwxyzABCDEFGHKLMNPQRSTUVWXYZ23456789
TRUST_PROXY=true
REDIS_ENABLED=true
#REDIS_HOST={{ env "NOMAD_IP_redis" }}
#REDIS_PORT={{ env "NOMAD_HOST_PORT_redis" }}
REDIS_PASSWORD=
REDIS_DB=0
DISALLOW_REGISTRATION=true
DISALLOW_ANONYMOUS_LINKS=false
CUSTOM_DOMAIN_USE_HTTPS=false
NON_USER_COOLDOWN=0
        EOT
        } 
        driver = "docker"
          config {            
            image = "kutt/kutt:v3.2.3"
            ports = [ "shorty" ]
          }
          service {
             tags = ["traefik.enable=true"]
             name = "shorty"
             port = "shorty"
             provider ="nomad"

           check {
              type = "tcp"
              port = "shorty"
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
       
       task "redis" {
         driver = "docker"
         config {
            image = "docker.io/valkey/valkey:9.0-alpine"
            ports = ["redis"]
          }
          service {
              tags = [ "${node.datacenter}"]
              name = "redis"
              port = "redis"
              provider ="nomad"

            check {
               type = "tcp"
               port = "redis"
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
