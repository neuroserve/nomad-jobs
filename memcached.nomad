job "memcached" { 
   datacenters = ["*"]

   group "group-memcached" {

      network {
         port "memcached" { 
           host_network = "overlay"
         }
      }

       task "task-memcached" {
         driver = "exec"
            config {
              command = "/usr/local/bin/memcached"
              args = [
                 "-l",
                 "${NOMAD_IP_memcached}",
                 "-p", 
                 "${NOMAD_PORT_memcached}"
              ]
            }

          service {
             tags = [ "${node.datacenter}" ] 
             name = "memcached"
             port = "memcached"
             provider = "nomad"
             address_mode = "auto"

            check {
              type = "tcp"
              port = "memcached"
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