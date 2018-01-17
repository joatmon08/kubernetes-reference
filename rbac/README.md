# k8s-rbac
This is a reference for implementing RBAC for a user, limited to a
specific namespace.

## Usage
* Run `./init.sh $CERT_PATH $CLUSTER $NAMESPACE $USERNAME`
* Update role.yml and rolebinding.yml with the correct namespace
and users.
* Apply to the cluster.
  ```
  kubectl apply -f role.yml
  kubectl delete -f rolebinding.yml
  ```
* To use the context, add the `--context` option.
  ```
  kubectl --context=$USERNAME-context get pods
  ```
