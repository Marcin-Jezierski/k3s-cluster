# Projekt: K3s Multi-node Cluster z nginx-ingress, MinIO i nginx-frontend

## Opis
Projekt uruchamia lokalny, multi-node klaster k3s z wykorzystaniem k3d, instalując trzy komponenty za pomocą Helm:
- Ingress Controller (nginx-ingress)
- MinIO jako obiektowy storage
- nginx-frontend – statyczny serwis zwracający przygotowany plik HTML z trzema obrazkami pobranymi z MinIO

## Wymagania
- Kubernetes CLI (kubectl)
- Helm
- mc (MinIO Client)
- k3d
- Docker lub inny kompatybilny container runtime

---

## Instrukcja uruchomienia

1. Sklonuj repozytorium:
```bash
git clone git@github.com:Marcin-Jezierski/k3s-cluster.git
cd k3s-cluster
```

2. Uruchom skrypt instalacyjny:
```bash
./install_script.sh
```

3. Jeśli skrypt nie zadziała poprawnie, możesz wykonać wszystkie kroki ręcznie:

### 1. Utwórz klaster K3D
```bash
k3d cluster create ha-cluster \
  --servers 3 \
  --agents 2 \
  -p "8086:80@loadbalancer" \
  --k3s-arg "--disable=traefik@server:*"
```

### 2. Zainstaluj ingress-nginx
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

### 3. Zainstaluj MinIO
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install minio bitnami/minio \
  --namespace minio --create-namespace \
  -f ./k3s/values/values-minio.yaml
```

### 4. Port-forward MinIO (w tle)
```bash
kubectl port-forward svc/minio 9000:9000 -n minio &
PORT_FORWARD_PID=$!
sleep 5
```

### 5. Skonfiguruj mc i wgraj obrazki
```bash
export MC_HOST_myminio="http://$(kubectl get svc/minio -n minio -o jsonpath='{.spec.clusterIP}'):9000"
mc alias set minio http://localhost:9000 admin PolskieRadio
mc cp ./assets/image* minio/my-test-bucket/
mc anonymous set public minio/my-test-bucket
```

### 6. Zakończ port-forward
```bash
kill "$PORT_FORWARD_PID"
```

### 7. Zastosuj HPA
```bash
kubectl apply -f ./k3s/hpa.yaml
```

### 8. Utwórz ConfigMap z frontendem
```bash
kubectl create configmap frontend-html --from-file=./assets/index.html -n minio
```

### 9. Zainstaluj frontend
```bash
helm upgrade --install frontend bitnami/nginx \
  --namespace minio --create-namespace \
  -f ./k3s/values/values-frontend.yaml
```

---

## `myapp.local:8086` z przeglądarki (Windows & Mac)

Aby uzyskać dostęp do aplikacji pod `myapp.local:8086`, wykonaj następujące kroki:

### Windows
1. Edytuj plik hosts:
```
C:\Windows\System32\drivers\etc\hosts
```
(z uprawnieniami administratora).

2. Dodaj linię:
```
127.0.0.1    myapp.local
```

3. Zapisz plik.

4. Otwórz Chrome i wejdź na:
```
http://myapp.local:8086
```

---

### Mac
1. Otwórz Terminal i edytuj plik hosts:
```bash
sudo nano /etc/hosts
```

2. Dodaj linię:
```
127.0.0.1    myapp.local
```

3. Zapisz i wyjdź (`Ctrl + O`, Enter, `Ctrl + X`).


4. Upewnij się, że aplikacja nasłuchuje na porcie 8080.

5. Otwórz Chrome i wejdź na:
```
http://myapp.local:8086
```
