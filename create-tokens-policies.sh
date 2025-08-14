nomad namespace apply ./autoscalerprod1.namespace.hcl
nomad namespace apply ./autoscalerprod4.namespace.hcl
nomad acl policy apply -namespace autoscalerprod1 -job autoscaler-ha-prod1 autoscalerprod1 autoscalerprod1-policy.hcl 
nomad acl policy apply -namespace autoscalerprod4 -job autoscaler-ha-prod4 autoscalerprod4 autoscalerprod4-policy.hcl 
nomad acl token create -name="autoscalerprod4" -policy=autoscalerprod4 -type=client
nomad acl token create -name="autoscalerprod1" -policy=autoscalerprod1 -type=client

nomad var put -in hcl -namespace autoscalerprod1 nomad/jobs/autoscaler-ha-prod1 @autoscalerprod1/spec.var.prod1.hcl cacert=@/etc/nomad/certificates/ca.pem clientcert=@/etc/nomad/certificates/cert.pem clientkey=@/etc/nomad/certificates/private_key.pem token=@autoscalerprod1.token
nomad var put -in hcl -namespace autoscalerprod4 nomad/jobs/autoscaler-ha-prod4 @autoscalerprod4/spec.var.prod4.hcl cacert=@/etc/nomad/certificates/ca.pem clientcert=@/etc/nomad/certificates/cert.pem clientkey=@/etc/nomad/certificates/private_key.pem token=@autoscalerprod4.token
