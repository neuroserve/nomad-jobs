job "haste" { 
   datacenters = ["prod1", "prod4"]

   group "haste" {
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
      network {
         port "memcachedp" {} 
         port "hastecontainer" { to = 7777 }
         port "caddy-http" { static = "8080" }
         port "caddy-https" { static = "8443" }
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
haste.code667.net {
        {{- range nomadService "haste"}}
        reverse_proxy {{ .Address }}:{{ .Port }}{{- end}} 

        tls hein@bloed.com
}
EOH
          destination = "local/Caddyfile"
         }
         service {
             tags = [ "${node.datacenter}"]
             name = "haste-caddy"
             port = "caddy-http"
             provider ="nomad"

#           check {
#              type = "tcp"
#              port = "caddy-http"
#              interval = "10s"
#              timeout = "2s"

#             check_restart {
#                limit = 3
#                grace = "90s"
#                ignore_warnings = "false"
#              }
#            }
          }
       }

       task "hastecontainer" {
         env {
          STORAGE_TYPE = "memcached"
          STORAGE_HOST = "${NOMAD_IP_memcachedp}"
          STORAGE_PORT = "${NOMAD_PORT_memcachedp}"
         }
         driver = "docker"
         config {              
            image = "somereg.net/haste/haste:2023022201"
            ports = [ "hastecontainer" ]
            auth {
              username = "tbueker"
              password = "BlaBla123"
            }
          }
          service {
             tags = [ "${node.datacenter}"]
             name = "haste"
             port = "hastecontainer"
             provider ="nomad"

           check {
              type = "tcp"
              port = "hastecontainer"
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
