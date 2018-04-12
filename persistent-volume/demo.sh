#!/usr/bin/env bash
. $(dirname ${BASH_SOURCE})/util.sh

desc "Create the StatefulSet."
run "kubectl apply -f statefulset.yaml"

volume=$(kubectl get pvc | grep www | tail -n 1 | cut -d' ' -f9)
minikube_ip=$(minikube ip)
token=$(kubectl describe secret $(kubectl get secrets | grep default | cut -f1 -d ' ') | grep -E '^token' | cut -f2 -d':' | xargs)

desc "Put some text for nginx to serve."
run "ssh -i ~/.minikube/machines/minikube/id_rsa docker@${minikube_ip} sudo 'echo Hello! > /tmp/hostpath-provisioner/"${volume}"/index.html'"

desc "Let's make a call to the nginx web server."
run "curl -k -H 'Authorization:Bearer ${token}' https://${minikube_ip}:8443/api/v1/namespaces/default/services/nginx:web/proxy/"

desc "Delete the StatefulSet."
run "kubectl delete -f statefulset.yaml --ignore-not-found"

desc "Does the volume and claim still exist?"
run "kubectl get pv"
run "kubectl get pvc"
run "kubectl get statefulsets"
run "ssh -i ~/.minikube/machines/minikube/id_rsa docker@${minikube_ip} cat /tmp/hostpath-provisioner/${volume}/index.html"
desc "Yes, the volume and claim still exist!"

desc "Let's bring the StatefulSet back up."
run "kubectl apply -f statefulset.yaml"

desc "Does the volume get reattached?"
desc "Let's make a call to the nginx web server."
run "curl -k -H 'Authorization:Bearer ${token}' https://${minikube_ip}:8443/api/v1/namespaces/default/services/nginx:web/proxy/"
desc "Yes, the volume is reattached."

desc "We'll back up the volume."
run "ssh -i ~/.minikube/machines/minikube/id_rsa docker@${minikube_ip} sudo cp -r /tmp/hostpath-provisioner/${volume} /tmp/${volume}-backup"

desc "Let's delete the backend volume, as if something went wrong."
run "ssh -i ~/.minikube/machines/minikube/id_rsa docker@${minikube_ip} sudo rm -rf /tmp/hostpath-provisioner/${volume}"

desc "Let's make a call to the nginx web server."
run "curl -k -H 'Authorization:Bearer ${token}' https://${minikube_ip}:8443/api/v1/namespaces/default/services/nginx:web/proxy/"

desc "Oh no!"
run "kubectl get pvc"
run "kubectl get pv"

desc "But yet the pvc and pv are still there..."
desc "Let's get more details on the actual persistent volume."
desc "Notice the HostPath that is specified."
run "kubectl describe pv ${volume}"

desc "There's a possibility that we can still fix the volume."
desc "Let's restore the volume, with our original index.html."
run "ssh -i ~/.minikube/machines/minikube/id_rsa docker@${minikube_ip} sudo cp -r /tmp/${volume}-backup /tmp/hostpath-provisioner/${volume}"

desc "The permissions need to be read/write/execute."
run "ssh -i ~/.minikube/machines/minikube/id_rsa docker@${minikube_ip} sudo chmod 777 /tmp/hostpath-provisioner/${volume}"

desc "Just in case, we'll check the claim and the volume."
run "kubectl get pvc"
run "kubectl get pv"

desc "Let's make a call to the nginx web server."
run "curl -k -H 'Authorization:Bearer ${token}' https://${minikube_ip}:8443/api/v1/namespaces/default/services/nginx:web/proxy/"

desc "Interesting, it didn't work. Maybe the pod needs to be restarted?"
run "kubectl delete pod web-0"

desc "Let's check if the pod came back up."
run "kubectl get pods"

desc "Let's make a call to the nginx web server."
run "curl -k -H 'Authorization:Bearer ${token}' https://${minikube_ip}:8443/api/v1/namespaces/default/services/nginx:web/proxy/"

desc "Let's delete everything now."
run "kubectl delete -f statefulset.yaml --ignore-not-found"
run "kubectl delete pv ${volume}"
run "kubectl delete pvc $(kubectl get pvc | grep web | cut -d' ' -f1)"