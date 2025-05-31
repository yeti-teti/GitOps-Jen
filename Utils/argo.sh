kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# To get the password
sudo apt install jq -y

# Get the external-ip from the svc type LoadBalancer and access the Argo CD
# Get IP or hostname
ARGOCD_SERVER_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ARGOCD_SERVER_HOSTNAME=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export ARGOCD_SERVER=${ARGOCD_SERVER_IP:-$ARGOCD_SERVER_HOSTNAME}

export ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# echo "Argo CD Server IP: https://$ARGOCD_SERVER"
# echo "Initial Argo CD admin password: $ARGO_PWD"

# Ensure jq is installed
# export ARGOCD_SERVER_JQ=$(kubectl get svc argocd-server -n argocd -o json | jq -r '.status.loadBalancer.ingress[0].hostname // .status.loadBalancer.ingress[0].ip')
# echo "Argo CD Server (using jq): https://$ARGOCD_SERVER_JQ"

# Use form CLI
# argocd login $ARGOCD_SERVER --username admin --password "$ARGO_PWD" --insecure

# Update password
# argocd account update-password --current-password "$ARGO_PWD" --new-password "<YOUR_NEW_STRONG_PASSWORD>"
