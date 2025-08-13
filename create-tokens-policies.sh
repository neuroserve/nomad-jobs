nomad namespace apply ./autoscalerprod1.namespace.hcl
nomad namespace apply ./autoscalerprod4.namespace.hcl
nomad acl policy apply -namespace autoscalerprod1 -job autoscaler-ha-prod1 autoscalerprod1 autoscalerprod1-policy.hcl 
nomad acl policy apply -namespace autoscalerprod4 -job autoscaler-ha-prod4 autoscalerprod4 autoscalerprod4-policy.hcl 
nomad acl token create -name="autoscalerprod4" -policy=autoscalerprod4 -type=client
nomad acl token create -name="autoscalerprod1" -policy=autoscalerprod1 -type=client

nomad var put -namespace autoscalerprod1 nomad/jobs/autoscaler-ha-prod1 cacert=@/etc/nomad/certificates/ca.pem clientcert=@/etc/nomad/certificates/cert.pem clientkey=@/etc/nomad/certificates/private_key.pem token=@autoscalerprod1.token osauthurl=@autoscalerprod1/osauthurl osusername=@autoscalerprod1/osusername ospassword=@autoscalerprod1/ospassword osdomainname=@autoscalerprod1/osdomainname osprojectid=@autoscalerprod1/osprojectid osregion=@autoscalerprod1/osregion
nomad var put -namespace autoscalerprod4 nomad/jobs/autoscaler-ha-prod4 cacert=@/etc/nomad/certificates/ca.pem clientcert=@/etc/nomad/certificates/cert.pem clientkey=@/etc/nomad/certificates/private_key.pem token=@autoscalerprod4.token osauthurl=@autoscalerprod4/osauthurl osusername=@autoscalerprod4/osusername ospassword=@autoscalerprod4/ospassword osdomainname=@autoscalerprod4/osdomainname osprojectid=@autoscalerprod4/osprojectid osregion=@autoscalerprod4/osregion
