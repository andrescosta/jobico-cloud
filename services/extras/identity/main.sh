helm repo add zitadel https://charts.zitadel.com
helm install my-zitadel zitadel/zitadel --values $1/values.yaml
