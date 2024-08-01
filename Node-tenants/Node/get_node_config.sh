#!/bin/bash

# Execute microk8s.add-node and get the last line of the output
output=$(microk8s.add-node | tail -n 1)

# Output the result in JSON format
echo "{\"output\": \"$output\"}"