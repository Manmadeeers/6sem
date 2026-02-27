package main

import (
	g02_02lib "GO02_02/G02_02lib"
	"fmt"
	"log"
	"net/http"
)

var A01 = 3

func handler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "A01 = %v\n", A01)
	fmt.Fprintf(w, "A02 = %t\n", A02)
	fmt.Fprintf(w, "A03 = %s\n", g02_02lib.A03)
}

func main() {
	http.HandleFunc("/", handler)
	addr := ":4000"

	log.Printf("Server running on http://localhost%s\n", addr)

	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
