 K8s Music Streaming Platform

Микросервисная платформа для стриминга музыки, развернутая в Kubernetes (Minikube).

 Что внутри?

Backend (Go): Управление треками, стриминг аудио с поддержкой перемотки (Range Requests), хранилище MinIO.

Frontend (Flutter Web): Мобильный дизайн в стиле Spotify, поиск песен, полноэкранный плеер, загрузка собственных треков.

Infrastructure: PostgreSQL для метаданных, MinIO для хранения файлов, всё упаковано в Kubernetes (Minikube).

 Быстрый запуск для команды
1. Предварительные требования

Убедитесь, что у вас установлены:

Docker, Minikube, kubectl

Flutter SDK (версия 3.x)

2. Запуск инфраструктуры (Бэкенд)

Запустите кластер:

code
Bash
download
content_copy
expand_less
minikube start
eval $(minikube docker-env)

Соберите бэкенд и разверните в K8s:

code
Bash
download
content_copy
expand_less
cd services
docker build -t streaming-service:latest .
cd ../k8s
kubectl apply -f .
3. Запуск Frontend

Перейдите в папку с приложением:

code
Bash
download
content_copy
expand_less
cd ../mobile_app

Установите зависимости:

code
Bash
download
content_copy
expand_less
flutter pub get

Запустите веб-сервер:

code
Bash
download
content_copy
expand_less
flutter run -d web-server --web-port 5000 --web-hostname 0.0.0.0

Откройте приложение: http://localhost:5000 (если локально) или по IP вашего сервера.
