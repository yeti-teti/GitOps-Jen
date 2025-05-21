# Helm
helm repo add stable https://charts.helm.sh/stable
# Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/prometheus
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana
# Edit the stable-kube-prometheus-sta-prometheus service to access from outside
kubectl patch svc stable-kube-prometheus-sta-prometheus -n default -p '{"spec": {"type": "LoadBalancer"}}'
# Grafana Pass
kubectl get secret -n default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
