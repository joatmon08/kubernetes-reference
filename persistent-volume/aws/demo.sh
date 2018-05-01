#!/usr/bin/env bash
. ../util.sh

desc "Create the StatefulSet."
run "kubectl apply -f statefulset.yaml"

volume=$(kubectl get pvc | grep hello | tail -n 1 | cut -d' ' -f9)
pvc=$(kubectl get pvc | grep hello | tail -n 1 | cut -d' ' -f1)
pod=$(kubectl get pods | grep hello | cut -d' ' -f1)

desc "Get the output of the stateful.log file."
run "kubectl exec ${pod} -- cat /usr/share/hello/stateful.log"

desc "Delete the StatefulSet."
run "kubectl delete -f statefulset.yaml --ignore-not-found"

desc "Does the volume and claim still exist?"
run "kubectl get pv"
run "kubectl get pvc"
run "kubectl get statefulsets"
desc "Yes, the volume and claim still exist!"

desc "Let's bring the StatefulSet back up."
run "kubectl apply -f statefulset.yaml"

desc "Does the volume get reattached?"
desc "Let's check the statefulset.log for previous log messages."
run "kubectl exec ${pod} -- cat /usr/share/hello/stateful.log"
desc "Yes, the volume is reattached."

desc "We'll back up the volume with an AWS snapshot."
volumeID=$(kubectl get pv ${volume} -o jsonpath='{.spec.awsElasticBlockStore.volumeID}' | cut -d'/' -f4)
run "aws ec2 create-snapshot --volume-id ${volumeID} --region=${REGION}"

desc "Let's capture the last known written log file line."
lastline=$(kubectl exec ${pod} -- cat /usr/share/hello/stateful.log | tail -n 1)

desc "Let's delete the statefulset, but keep the pvc & pv."
run "kubectl delete -f statefulset.yaml"
desc "And let's delete the backend volume, as if something went wrong."
run "aws ec2 delete-volume --volume-id ${volumeID} --region=${REGION}"

desc "What happens when I access my stateful logs?"
run "kubectl exec ${pod} -- cat /usr/share/hello/stateful.log"

desc "Oh no!"
run "kubectl get pvc"
run "kubectl get pv"

desc "But yet the pvc and pv are still there..."

desc "There's a possibility that we can create a new statefulset and reattach the volume."
desc "Let's restore the volume with our snapshot."
run "aws ec2 create-volume --availability-zone=${REGION}a --snapshot-id ${snapshotID} --region=${REGION} --volume-type gp2 --tag-specifications 'ResourceType=volume,Tags=[{Key=KubernetesCluster,Value=joatmon08.k8s.local}]'"

desc "Let's add the new volume ID to the pv.yaml and create it."
run "kubectl apply -f pv.yaml"

desc "Let's apply the pv claim."
run "kubectl apply -f pv-claim.yaml"

desc "We'll delete the old pvc and pv."
run "kubectl delete pvc ${pvc}"
run "kubectl delete pv ${volume}"

desc "Does it show the original state?"
run "kubectl exec ${pod} -- cat /usr/share/hello/stateful.log"
desc "YES!"

desc "Let's delete everything now."
run "kubectl delete -f statefulset.yaml --ignore-not-found"
run "kubectl delete -f statefulset-restore.yaml --ignore-not-found"
run "kubectl delete -f pv.yaml --ignore-not-found"
run "kubectl delete -f pv-claim.yaml --ignore-not-found"
