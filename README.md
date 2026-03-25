
# K8s Music Streaming Platform

Микросервисная платформа для стриминга музыки, развернутая в **Kubernetes (Minikube)**.

---

##  Основные компоненты
* **Backend (Go)**: Управление треками, поддержка `Range Requests` (перемотка), хранилище MinIO.
* **Frontend (Flutter Web)**: Мобильный дизайн в стиле Spotify, поиск песен, полноэкранный плеер.
* **Infrastructure**: PostgreSQL, MinIO, Kubernetes.

---

##  Быстрый запуск

### 1. Инфраструктура

minikube start
eval $(minikube docker-env)

2. Бэкенд

cd services
docker build -t streaming-service:latest .
cd ../k8s
kubectl apply -f .

3. Фронтенд

cd ../mobile_app
flutter pub get
flutter run -d web-server --web-port 5000
