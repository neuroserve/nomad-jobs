job "yopa" { 
   datacenters = ["prod1", "prod4"]

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
         port "memcachedpy" {
           to = 11211
           host_network="overlay"
         }
         port "yopa" { 
           to = 1337
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
              "--memcached", "${NOMAD_ADDR_memcachedpy}"
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
       
       task "memcachedpy" {
         driver = "exec"
         config {
            command = "/usr/local/bin/memcached"
            args = [
              "-o",
              "proxy_config=routelib,proxy_arg=local/config.lua",
            ]
          }

         template {
            data = <<EOH
pools{
    set_all = {
        {  backends = { 
            {{- range nomadService "memcached-prod1" }}
              "{{ .Address }}:{{ .Port }}"{{- end}} 
            } 
        },
        {  backends = {
            {{- range nomadService "memcached-prod4" }}
              "{{ .Address }}:{{ .Port }}"{{- end}}
           }
        },
    }
}
routes{
    cmap = {
        get = route_failover{
            children = "set_all",
            stats = true,
            miss = true,
            shuffle = true,
            failover_count = 2
        },
    },
    default = route_allsync{ 
            children = "set_all",
    },
}
            EOH
            
            destination = "local/config.lua"
         } 

         service {
             tags = [ "${node.datacenter}"]
             name = "memcachedpy"
             port = "memcachedpy"
             provider ="nomad"

           check {
              type = "tcp"
              port = "memcachedpy"
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
