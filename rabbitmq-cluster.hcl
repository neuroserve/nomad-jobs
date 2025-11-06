job "rabbitmq-cluster" {
  
  datacenters = [ "prod1", "prod4", "de-gt-2" ]
  type = "service"

  group "rabbitmq" {
    count = 3
    constraint {
      operator = "distinct_hosts"
      value = "true"
    }

    network {
      port "amqp" {
        host_network = "overlay"
        static = 5672
      }
      port "ui" {
        host_network = "overlay"
        static = 15672
      }
      port "epmd" {
        host_network = "overlay"
        static = 4369
      }
      port "clustering" {
        host_network = "overlay"
        static = 25672
      }
    }

    service {
      name = "rabbitmq"
      port = "amqp"

      tags = [ "v1" ]
      check {
        type     = "tcp"
        port     = "amqp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "rabbitmq" {
      driver = "docker"
      
      template {
        destination = "secrets/secret.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
DOCKER_USER = {{ with nomadVar "nomad/jobs/rabbitmq-cluster" }}{{ .username }}{{ end }}
DOCKER_PASS = {{ with nomadVar "nomad/jobs/rabbitmq-cluster" }}{{ .password }}{{ end }}
        EOH
        }
      
      env {
        RABBITMQ_ERLANG_COOKIE = "secret_cookie"
        RABBITMQ_DEFAULT_USER = "test"
        RABBITMQ_DEFAULT_PASS = "test"
        # RABBITMQ_USE_LONG_NAME = "true"
        # CONSUL_HOST = "${attr.unique.network.ip-address}"
      }

      config {
        image = "reg.code667.net/rabbitmq/rabbitmq-consul:2025110302"
        hostname = "${attr.unique.hostname}"
        ports = [ "ui", "epmd", "clustering", "amqp" ]
        extra_hosts = ["nomad-client-prod1-0:100.102.0.23", "nomad-client-prod4-0:100.102.0.22", "nomad-client-triton-1:100.102.0.5"]
      }
        
      resources {
        cpu    = 500 # 500 MHz
        memory = 512 # 512MB
      }
    }
  }  
}
