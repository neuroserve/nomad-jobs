job "memcached-de-gt-2" { 
   datacenters = ["de-gt-2"]

   group "group-memcached-de-gt-2" {

      network {
         port "memcached" { 
           host_network = "overlay"
         }
      }

       task "task-memcached-de-gt-2" {
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
             name = "memcached-de-gt-2"
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
