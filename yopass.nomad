job "yopa" { 
   datacenters = ["prod1", "prod4"]

   update {
     max_parallel = 1
     stagger      = "1m"
     auto_revert  = true
   }

   group "yopa" {
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
      constraint {
        operator = "distinct_hosts"
        value = "true"
      }
      network {
         mode = "bridge"
         port "yopa" { 
           to = 1337
           host_network="overlay"
         }
         port "redisy" {
           to     = 6379
           host_network="overlay"
         }
       }

       task "yopa" {
        # env {
        #  YOPASS_DATABASE = "memcached"
        #  YOPASS_MEMCACHED = "${NOMAD_ADDR_memcachedp}"
        # }
         driver = "docker"
         config {              
            image = "jhaals/yopass:11.19.1"
            ports = [ "yopa" ]
            args = [
              "--database", "redis",
#             "--redis", "redis://${NOMAD_ADDR_redisy}/"
            ]
          }
          service {
             tags = ["traefik.enable=true"]
             name = "yopa"
             port = "yopa"
             provider ="nomad"

             check {
                type = "tcp"
                port = "yopa"
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
       
       task "redisy" {
         driver = "docker"
         config {
            image = "redis:7-alpine"
            ports = [ "redisy" ]
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
             name = "redisy"
             port = "redisy"
             provider ="nomad"

           check {
              type = "tcp"
              port = "redisy"
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
