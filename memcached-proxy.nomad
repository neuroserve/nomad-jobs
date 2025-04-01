job "haste" { 
   datacenters = ["dc1"]

   group "haste" {

      network {
         port "memcachedp" {} 
      }

       task "memcached-proxy" {
         driver = "exec"
            config {
              command = "/usr/local/bin/memcached"
              args = [
                "-l",
                 "${NOMAD_IP_memcachedp}",
                 "-p", 
                 "${NOMAD_PORT_memcachedp}",
                 "-o",
                 "proxy_config=routelib,proxy_arg=local/config.lua",
              ]
            }

         template {
            data = <<EOH
pools{
    set_all = {
        {  backends = { 
            {{- range nomadService "memcached-group-memcached-task-memcached" }}
              "{{ .Address }}:{{ .Port }}"{{- end}} 
            } 
        },
        {  backends = {
            {{- range nomadService "memcached-group-memcached-task-memcached" }}
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
             name = "memcached-proxy"
             port = "memcachedp"
             provider ="nomad"

           check {
              type = "tcp"
              port = "memcachedp"
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
