package main

import (
	"GO02_01/go02_01lib"
	"fmt"
	"log"
	"net/http"
)

const C01 = 3.14

func handler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "C01 = %v\n", C01)
	fmt.Fprintf(w, "C02 = %e\n", C02)
	fmt.Fprintf(w, "C03 = %v\n", go02_01lib.C03)

}

func main() {
	http.HandleFunc("/", handler)
	addr := ":3000"

	log.Printf("Server running on http://localhost%s\n", addr)

	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
