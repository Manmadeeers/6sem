package main

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/gorilla/mux"
)

type JRPCRequest struct {
	JSONRPC string          `json:jsonrpc`
	Method  string          `json:method`
	Params  json.RawMessage `json:params,omitempty`
	Id      interface{}     `json: id,omitempty`
}

type JRPCResponse struct {
	JSONRPC string      `json:jsonrpc`
	Result  interface{} `json:result,omitempty`
	Error   *RPCError   `json:"error,omitempty"`
	ID      interface{} `json:"id"`
}

type RPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func RPCHandler(w http.ResponseWriter, r *http.Request) {

}

func main() {
	router := mux.NewRouter()
	router.HandleFunc("/jrpc", RPCHandler).Methods(http.MethodPost)

	port := ":3000"

	log.Printf("Server running at http://localhost%s", port)

	if err := http.ListenAndServe(port, router); err != nil {
		log.Print("Server failed to start")
	}
}
