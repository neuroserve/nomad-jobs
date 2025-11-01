job "yopa" { 
   datacenters = ["prod1"]

   group "yopa" {
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
         port "memcachedp" {}
         port "yopacontainer" { 
          host_network = "local"
          to = 1337
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
yopa.code667.net {
        {{- range nomadService "yopa" }}
        reverse_proxy {{ .Address }}:{{ .Port }}{{- end}} 

        tls hein@bloed.com
}
yopa.waechterrat.de {
        {{- range nomadService "yopa" }}
        reverse_proxy {{ .Address }}:{{ .Port }}{{- end}} 

        tls hein@bloed.com
}
EOH
          destination = "local/Caddyfile"
         }
       }

       task "yopacontainer" {
        # env {
        #  YOPASS_DATABASE = "memcached"
        #  YOPASS_MEMCACHED = "${NOMAD_ADDR_memcachedp}"
        # }
         driver = "docker"
         config {              
            image = "jhaals/yopass:11.19.1"
            ports = [ "yopacontainer" ]
            args = [
              "--memcached", "${NOMAD_ADDR_memcachedp}"
            ]
          }
          service {
             tags = [ "${node.datacenter}"]
             name = "yopa"
             port = "yopacontainer"
             provider ="nomad"

           check {
              type = "tcp"
              port = "yopacontainer"
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
            {{- range nomadService "memcached-prod1" }}
              "{{ .Address }}:{{ .Port }}"{{- end}} 
            } 
        },
        {  backends = {
            {{- range nomadService "memcached-prod4" }}
              "{{ .Address }}:{{ .Port }}"{{- end}}
           }
        },
        {  backends = {
            {{- range nomadService "memcached-de-gt-2" }}
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
