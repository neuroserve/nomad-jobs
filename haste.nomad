job "haste" { 
   datacenters = ["prod1", "prod4"]

   update {
     max_parallel = 1
     stagger      = "1m"
     auto_revert  = true
   }


   group "haste" {
      count = 1
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
         port "haste" { 
           to = 7777 
           host_network="overlay"
         }
         port "redish" {
           to     = 6379
           host_network="overlay"
         }
      }

       task "haste" {
         env {
          STORAGE_TYPE = "redis"
          STORAGE_HOST = "localhost"
          STORAGE_PORT = 6379 
          # STORAGE_PASSWORD=grzlbrmpf
         }

         template {
           destination = "secrets/secret.env"
           env         = true
           change_mode = "restart"
           data        = <<EOH
DOCKER_USER = {{ with nomadVar "nomad/jobs/haste" }}{{ .username }}{{ end }}
DOCKER_PASS = {{ with nomadVar "nomad/jobs/haste" }}{{ .password }}{{ end }}
           EOH
         }
         
         driver = "docker"
         config {              
            image = "reg.code667.net/haste/haste:2023022201"
            ports = [ "haste" ]
          }
          service {
             tags = ["traefik.enable=true"]
             name = "haste"
             port = "haste"
             provider ="nomad"

           check {
              type = "tcp"
              port = "haste"
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

       task "redish" {
         driver = "docker"
         config {
            image = "redis:7-alpine"
            ports = [ "redish" ]
            args = [
              "redis-server",
              "--maxmemory", "200mb",
              "--maxmemory-policy", "allkeys-lru",
              "--appendonly", "yes",
            ]
         }
         resources {
           cpu = 500
           memory = 256
         }

         service {
             tags = [ "${node.datacenter}", "cache", "db"]
             name = "redish"
             port = "redish"
             provider ="nomad"

           check {
              type = "tcp"
              port = "redish"
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





