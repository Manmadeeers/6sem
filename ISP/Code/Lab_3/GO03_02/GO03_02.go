package main

import (
	P0302 "GO03_02/P03_02"
	"fmt"
	"log"
	"net/http"
)

func main() {
	var stats P0302.Stats

	mux := http.NewServeMux()

	mux.HandleFunc("/S", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			stats.PlusGet()
		case http.MethodPost:
			stats.PlusPost()
		default:
			w.WriteHeader(http.StatusMethodNotAllowed)
			w.Header().Set("Allow", "GET,POST")
			return
		}
		fmt.Fprintf(w, "Successfully incremented")
		fmt.Println("Successfully incremented")
	})

	mux.HandleFunc("/G", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			w.Header().Set("Allow", http.MethodGet)
			return
		}
		w.Header().Set("Content-type", "text/plain;charset=utf-8")
		fmt.Fprintln(w, stats.GetStr())
	})

	port := ":3000"
	log.Printf("Server running at http://localhost%s", port)

	if err := http.ListenAndServe(port, mux); err != nil {
		log.Fatalf("Server error: %v", err)
	}

}
