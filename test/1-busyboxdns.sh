kubectl run busybox --image=busybox:1.28 --command -- sleep 3600
#kubectl get pods -l run=busybox
kubectl exec -ti busybox -- nslookup kubernetes
#
