package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgconn"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var db *gorm.DB

type Celebrity struct {
	Id int `gorm:"primaryKey;column:id" json:"Id"`

	FullName string `gorm:"column:fullname" json:"FullName"`

	Nationality string `gorm:"column:nationality" json:"Nationality"`

	ReqPhotoPath string `gorm:"column:reqphotopath" json:"ReqPhotoPath"`
}

func initDB() {
	connString := "host=localhost user=postgres password=pass dbname=celebrities_db port=5432 sslmode=disable"

	var err error
	db, err = gorm.Open(postgres.Open(connString), &gorm.Config{})
	if err != nil {
		log.Printf("Failed to initialize database: %v", err)
	}

	fmt.Print("Connection Successfull\n")
}

func GetAllCelebritiesHandler(w http.ResponseWriter, r *http.Request) {
	var celebrities []Celebrity

	if err := db.Find(&celebrities).Error; err != nil {
		log.Printf("Failed to get all celebrities: %v", err)
		http.Error(w, "Failed to get the complete list of data", http.StatusInternalServerError)
		return
	}
	json.NewEncoder(w).Encode(celebrities)
}

func GetCelebrityByIdHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	idStr := vars["id"]

	var c Celebrity

	if err := db.First(&c, idStr).Error; err != nil {
		log.Printf("Failed to get a celebrity by id: %v", err)
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "Celebrity with this ID could not be found", http.StatusNotFound)
			return
		}

		http.Error(w, "Failed to get a celebrity by id", http.StatusInternalServerError)
		return
	}
	json.NewEncoder(w).Encode(c)

}

func AddCelebrityHandler(w http.ResponseWriter, r *http.Request) {
	var newCelebrity Celebrity

	err := json.NewDecoder(r.Body).Decode(&newCelebrity)
	if err != nil {
		log.Printf("Failed to decode JSON: %v", err)
		http.Error(w, "Failed to decode JSON body", http.StatusBadRequest)
		return
	}

	result := db.Create(&newCelebrity)
	if result.Error != nil {
		log.Printf("Failed to add a new Celebrity: %v", err)

		if pgErr, ok := result.Error.(*pgconn.PgError); ok {
			if pgErr.Code == "23505" {
				http.Error(w, "Celebrity with this id already exists", http.StatusConflict)
				return
			}
		}
		http.Error(w, "Failed to add a new Celebtiry", http.StatusInternalServerError)
		return

	}

	json.NewEncoder(w).Encode(newCelebrity)

}

func UpdateCelebrityHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	idStr := vars["id"]

	var celebrity Celebrity

	if err := db.First(&celebrity, idStr).Error; err != nil {
		log.Printf("Element to update not found: %v", err)
		http.Error(w, "Element to update not found", http.StatusNotFound)
		return
	}

	json.NewDecoder(r.Body).Decode(&celebrity)
	db.Save(&celebrity)
	json.NewEncoder(w).Encode(celebrity)
}

func DeleteCelebrityHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	idStr := vars["id"]

	result := db.Delete(&Celebrity{}, idStr)
	if result.RowsAffected == 0 {
		log.Print("Element to delete not found")
		http.Error(w, "Element to delete not found", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusOK)
}

func main() {
	initDB()

	router := mux.NewRouter()
	router.HandleFunc("/Celebrities/All", GetAllCelebritiesHandler).Methods(http.MethodGet)
	router.HandleFunc("/Celebrities/{id:[0-9]+}", GetCelebrityByIdHandler).Methods(http.MethodGet)
	router.HandleFunc("/Celebrities", AddCelebrityHandler).Methods(http.MethodPost)
	router.HandleFunc("/Celebrities/{id:[0-9]+}", UpdateCelebrityHandler).Methods(http.MethodPut)
	router.HandleFunc("/Celebrities/{id:[0-9]+}", DeleteCelebrityHandler).Methods(http.MethodDelete)

	port := ":3000"

	log.Printf("Server running at http://localhost:%s", port)

	if err := http.ListenAndServe(port, router); err != nil {
		log.Print("Server failed to start")
	}
}
