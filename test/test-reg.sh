 kubectl run nginx-pod --image=reg.jobico.org/mynginx:v1 --overrides='{ "apiVersion": "v1", "spec": { "imagePullSecrets": [{"name": "reg-cred-secret"}] } }'
