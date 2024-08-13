#!/bin/bash

hash_value=$( openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
token_value=$(kubeadm token create)

output="kubeadm join 192.168.0.9:6443 --token $token_value --discovery-token-ca-cert-hash sha256:$hash_value"
# Output the result in JSON format
echo "{\"output\": \"$output\"}"

