job "haste" { 
   datacenters = ["prod1", "prod4"]

   group "haste" {
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
         port "memcachedph" {
           to = 11211         
           host_network="overlay"
         } 
         port "haste" { 
           to = 7777 
           host_network="overlay"
         }
      }

       task "haste" {
         env {
          STORAGE_TYPE = "memcached"
#          STORAGE_HOST = "${NOMAD_IP_memcachedp}"
#          STORAGE_PORT = "${NOMAD_PORT_memcachedp}"
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
       
       task "memcachedph" {
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
            {{- range nomadService "memcached-prod1"}}
              "{{ .Address }}:{{ .Port }}"{{- end}} 
            } 
        },
        {  backends = {
            {{- range nomadService "memcached-prod4"}}
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
             name = "memcachedph"
             port = "memcachedph"
             provider ="nomad"

           check {
              type = "tcp"
              port = "memcachedph"
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
