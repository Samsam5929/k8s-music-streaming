package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	_ "github.com/lib/pq"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type Track struct {
	ID       int    `json:"id"`
	Title    string `json:"title"`
	Artist   string `json:"artist"`
	MinioKey string `json:"minio_key"`
}

func main() {
	// 1. Подключение к Postgres
	dbConnStr := "host=postgres-service port=5432 user=admin password=admin123 dbname=music_db sslmode=disable"
	db, err := sql.Open("postgres", dbConnStr)
	if err != nil {
		log.Fatalf("Ошибка БД: %v", err)
	}

	// 2. Подключение к MinIO
	endpoint := os.Getenv("MINIO_ENDPOINT")
	minioClient, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4("admin", "password123", ""),
		Secure: false,
	})
	if err != nil {
		log.Fatalf("Ошибка MinIO: %v", err)
	}

	// --- ЭНДПОИНТ: Список треков из базы ---
	http.HandleFunc("/tracks", func(w http.ResponseWriter, r *http.Request) {
		rows, err := db.Query("SELECT id, title, artist, minio_key FROM tracks")
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		defer rows.Close()

		var tracks []Track
		for rows.Next() {
			var t Track
			rows.Scan(&t.ID, &t.Title, &t.Artist, &t.MinioKey)
			tracks = append(tracks, t)
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Access-Control-Allow-Origin", "*") // Для мобилки
		json.NewEncoder(w).Encode(tracks)
	})

	// --- ЭНДПОИНТ: Стриминг файла ---
	http.HandleFunc("/stream", func(w http.ResponseWriter, r *http.Request) {
		filename := r.URL.Query().Get("key")
		if filename == "" {
			filename = "test.mp3"
		}

		objInfo, err := minioClient.StatObject(context.Background(), "music", filename, minio.StatObjectOptions{})
		if err != nil {
			http.Error(w, "File not found", http.StatusNotFound)
			return
		}

		object, _ := minioClient.GetObject(context.Background(), "music", filename, minio.GetObjectOptions{})
		defer object.Close()

		w.Header().Set("Content-Type", "audio/mpeg")
		w.Header().Set("Content-Length", fmt.Sprintf("%d", objInfo.Size))
		w.Header().Set("Accept-Ranges", "bytes")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		io.Copy(w, object)
	})

	fmt.Println("Сервер v2 запущен на :8080...")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
