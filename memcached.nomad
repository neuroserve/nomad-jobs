job "memcached" { 
   datacenters = ["dc1"]

   group "group-memcached" {

      network {
         port "memcached" {} 
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
             port = "memcached"
             provider ="nomad"

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