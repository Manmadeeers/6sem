package main

import (
	"encoding/json"
	"fmt"
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

func GetCelebrityByIdHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	idStr := vars["id"]

	jsonFile, err := os.Open("Celebrities.json")
	if err != nil {
		log.Printf("Failed to read Celebrities.json: %v", err)
		http.Error(w, "Failed to read Celebrities.json", http.StatusInternalServerError)
		return
	}

	defer jsonFile.Close()

	byteValue, _ := io.ReadAll(jsonFile)
	var celebrities []Celebrity
	if err := json.Unmarshal(byteValue, &celebrities); err != nil {
		log.Printf("Failed to pricess json data: %v", err)
		http.Error(w, "Failed to process json data", http.StatusInternalServerError)
		return
	}

	for _, c := range celebrities {
		if fmt.Sprintf("%d", c.Id) == idStr {
			w.Header().Set("Content-type", "application/json")
			json.NewEncoder(w).Encode(c)
			return
		}
	}

	http.Error(w, "Celebrity not found", http.StatusNotFound)
}

func AddCelebrityHandler(w http.ResponseWriter, r *http.Request) {
	var newCelebrity Celebrity

	if err := json.NewDecoder(r.Body).Decode(&newCelebrity); err != nil {
		log.Printf("Incorrect JSON format: %v", err)
		http.Error(w, "Incorrect JSON format", http.StatusBadRequest)
		return
	}

	jsonFile, err := os.ReadFile("Celebrities.json")
	if err != nil && !os.IsNotExist(err) {
		log.Printf("Failed to read JSON file: %v", err)
		http.Error(w, "Failed to read JSON file", http.StatusInternalServerError)
		return
	}

	var celebrities []Celebrity
	if len(jsonFile) > 0 {
		json.Unmarshal(jsonFile, &celebrities)
	}

	for _, c := range celebrities {
		if c.Id == newCelebrity.Id {
			w.Header().Set("Content-type", "application/json")
			w.WriteHeader(http.StatusConflict)
			fmt.Fprintf(w, `{"status": 409, "message": "ID %d alrwady exists"}`, newCelebrity.Id)
			return
		}

		celebrities = append(celebrities, newCelebrity)
		updatedData, _ := json.MarshalIndent(celebrities, "", "	")
		os.WriteFile("Celebrities.json", updatedData, 0644)

		w.Header().Set("Content-type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(newCelebrity)
	}
}

func UpdateCelebrityHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	idStr := vars["id"]
	var updatedCelebrity Celebrity

	if err := json.NewDecoder(r.Body).Decode(&updatedCelebrity); err != nil {
		http.Error(w, "Incorrect JSON", http.StatusBadRequest)
		return
	}

	jsonFile, err := os.ReadFile("Celebrities.json")
	if err != nil {
		log.Printf("Failed to read Celebrities.json: %v", err)
		http.Error(w, "Failed to read Celebrities.json", http.StatusInternalServerError)
		return
	}

	var celebrities []Celebrity
	json.Unmarshal(jsonFile, &celebrities)

	found := false
	for i, c := range celebrities {
		if fmt.Sprintf("%d", c.Id) == idStr {
			updatedCelebrity.Id = c.Id
			celebrities[i] = updatedCelebrity
			found = true
			break
		}
	}

	if !found {
		w.Header().Set("Content-type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		fmt.Fprintf(w, `{"status": 404, "message": "Элемент с ID %s не найден"}`, idStr)
		return
	}

	newData, _ := json.MarshalIndent(celebrities, "", "	")
	os.WriteFile("Celebrities.json", newData, 0644)
	w.Header().Set("Content-type", "application/json")
	json.NewEncoder(w).Encode(updatedCelebrity)
}

func DeleteCelebrityHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	idStr := vars["id"]

	jsonFile, err := os.ReadFile("Celebrities.json")
	if err != nil {
		http.Error(w, "Failed to read Celebrities.json", http.StatusInternalServerError)
		return
	}

	var celebrities []Celebrity
	json.Unmarshal(jsonFile, &celebrities)

	found := false
	var updatedCelebrities []Celebrity
	for _, c := range celebrities {
		if fmt.Sprintf("%d", c.Id) == idStr {
			found = true
			continue
		}
		updatedCelebrities = append(updatedCelebrities, c)
	}

	if !found {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		fmt.Fprintf(w, `{"status": 404, "message": "Element with ID %s not found"}`, idStr)
		return
	}

	newData, _ := json.MarshalIndent(updatedCelebrities, "", "    ")
	os.WriteFile("Celebrities.json", newData, 0644)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"status": 200, "message": "Element with ID %s successfully deleted"}`, idStr)
}

func main() {
	router := mux.NewRouter()
	router.HandleFunc("/Celebrities/All", GetAllCelebritiesHandler).Methods(http.MethodGet)
	router.HandleFunc("/Celebrities/{id:[0-9]+}", GetCelebrityByIdHandler).Methods(http.MethodGet)
	router.HandleFunc("/Celebrities", AddCelebrityHandler).Methods(http.MethodPost)
	router.HandleFunc("/Celebrities/{id:[0-9]+}", UpdateCelebrityHandler).Methods(http.MethodPut)
	router.HandleFunc("/Celebrities/{id:[0-9]+}", DeleteCelebrityHandler).Methods(http.MethodDelete)

	port := ":3000"
	log.Printf("Server running at http://localhost%s", port)

	if err := http.ListenAndServe(port, router); err != nil {
		log.Fatal("Critical server error: ", err)
	}
}
