# Create namespace for monitoring
kubectl create namespace monitoring

# Helm
helm repo add stable https://charts.helm.sh/stable

# Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/prometheus
helm install prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring

# Grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana

# Edit the stable-kube-prometheus-sta-prometheus service to access from outside
kubectl patch svc prometheus-stack-kube-prom-prometheus -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
# kubectl get svc -n monitoring 

# Check pods
# Make sure old test of prometheus node exporter running in another namespace are not running by accident.
# kubectl get po --all-namespaces -o=jsonpath="{range .items[*]}{.spec.nodeName}{'\t'}{.spec.hostNetwork}{'\t'}{.metadata.namespace}{'\t'}{.metadata.name}{'\t'}{.spec.hostNetwork}{'\t'}{.spec.containers..containerPort}{'\n'}{end}"
# helm uninstall prometheus

# Grafana patch and Pass
kubectl patch svc prometheus-stack-grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
# kubectl get svc prometheus-stack-grafana -n monitoring

# Get prometheus-stack Grafana password
kubectl get secret prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode ; echo