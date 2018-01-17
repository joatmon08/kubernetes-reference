#!/bin/bash

if [ $# -ne 4 ]; then
    echo "Got ${#} arguments"
    exit 1
fi

CERT_PATH=$1
CLUSTER=$2
NAMESPACE=$3
USERNAME=$4

client_cert=$1/$2/ca.crt
client_key=$1/$2/ca.key

kubectl create namespace $NAMESPACE
openssl genrsa -out user.key 4096
openssl req -new -key user.key -out user.csr -subj "/CN=$USERNAME/O=developer"
openssl x509 -req -in user.csr -CA $client_cert -CAkey $client_key -CAcreateserial -out user.crt -days 10
kubectl config set-credentials $USERNAME --client-certificate=user.crt --client-key=user.key
kubectl config set-context $USERNAME-context --cluster=$CLUSTER --namespace=$NAMESPACE --user=$USERNAME
