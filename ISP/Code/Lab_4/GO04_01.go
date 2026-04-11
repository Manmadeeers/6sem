package main

import (
	"io"
	"log"
	"net/http"
	"os"

	"github.com/gorilla/mux"
)

type Celebrity struct {
	Id int `json:"id"`

	FullName string `json:"FullName"`

	Nationality string `json:"Nationality"`

	ReqPhotoPath string `json:"ReqPhotoPath"`
}

func GetAllCelebritiesHandler(w http.ResponseWriter, r *http.Request) {
	jsonFile, err := os.Open("Celebrities.json")
	if err != nil {
		log.Printf("Celebrities.json file not found: %v", err)
		http.Error(w, "Data file not found", http.StatusNotFound)
		return
	}
	defer jsonFile.Close()

	byteValue, err := io.ReadAll(jsonFile)
	if err != nil {
		log.Printf("Failed to read bytes from jsonFile: %v", err)
		http.Error(w, "Failed to read bytes from jsonFile", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(byteValue)

}

func GetCelebrityById(w http.ResponseWriter, r *http.Request) {

}

func main() {
	router := mux.NewRouter()
	router.HandleFunc("/Celebrities/All", GetAllCelebritiesHandler).Methods(http.MethodGet)

	port := ":3000"
	log.Printf("Server running at http://localhost%s", port)

	if err := http.ListenAndServe(port, router); err != nil {
		log.Fatal("Critical server error: ", err)
	}
}
