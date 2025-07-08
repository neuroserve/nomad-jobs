namespace "autoscalerprod4" {
  policy = "write"
  variables {
    path "*" {
      capabilities = ["write", "read", "destroy"]
    }
  }
}

agent {
  policy = "write"
}

node {
  policy = "read"
}

quota {
  policy = "read"
}


