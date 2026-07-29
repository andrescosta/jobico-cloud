helm uninstall my-zitadel
for resource in job configmap secret rolebinding role serviceaccount; do
  kubectl delete $resource --selector app.kubernetes.io/name=zitadel
done

kubectl get all,secret,configmap,job -l app.kubernetes.io/name=zitadel

psql "postgresql://postgres:postgres@db.jobico.local:5432/postgres?sslmode=require" -c "DROP DATABASE zitadel WITH (FORCE);"

