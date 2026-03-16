package main

import (
	"fmt"
	"log"
	"net/http"
	"strings"
)

func handler(w http.ResponseWriter, r *http.Request) {
	allowed := []string{"GET", "POST", "PUT"}
	allowedURI := []string{"/A", "/A/B", "/"}

	uriAllowed := false
	for _, m := range allowedURI {
		if r.URL.Path == m {
			uriAllowed = true
			break
		}
	}

	if !uriAllowed {
		http.NotFound(w, r)
		return
	}

	isAllowed := false
	for _, m := range allowed {
		if r.Method == m {
			isAllowed = true
			break
		}
	}

	if !isAllowed {
		w.Header().Set("Allow", strings.Join(allowed, ","))
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	message := fmt.Sprintf("Method: %s, Route: %s", r.Method, r.URL.Path)
	log.Println(message)
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "Request processed. %s\n", message)
}

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/A", handler)
	mux.HandleFunc("/A/B", handler)
	mux.HandleFunc("/", handler)

	port := ":3000"

	log.Printf("Server running at http://localhost%s", port)

	if err := http.ListenAndServe(port, mux); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}
