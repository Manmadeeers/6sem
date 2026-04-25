package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"

	"github.com/gorilla/mux"
)

type JRPCRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
	Id      interface{}     `json: "id,omitempty"`
}

type JRPCResponse struct {
	JSONRPC string      `json:"jsonrpc"`
	Result  interface{} `json:"result,omitempty"`
	Error   *RPCError   `json:"error,omitempty"`
	ID      interface{} `json:"id"`
}

type RPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

var (
	precision      int = 2
	precisionMutex sync.RWMutex
)

func resultFormatter(val float64) float64 {
	precisionMutex.RLock()
	defer precisionMutex.RUnlock()

	format := fmt.Sprintf("%%.%df", precision)
	var res float64
	fmt.Sscanf(fmt.Sprintf(format, val), "%f", &res)
	return res
}

func RPCHandler(req JRPCRequest) *JRPCResponse {
	if req.JSONRPC != "2.0" {
		return &JRPCResponse{JSONRPC: "2.0", ID: req.Id, Error: &RPCError{-32600, "Invalid Request"}}
	}
	var result interface{}
	var rpcErr *RPCError

	switch req.Method {
	case "sum", "sub", "mul", "div":
		var p []float64
		if err := json.Unmarshal(req.Params, &p); err != nil || len(p) < 2 {
			rpcErr = &RPCError{-32602, "Invalid parameters"}
		} else {
			switch req.Method {
			case "sum":
				result = resultFormatter(p[0] + p[1])
			case "sub":
				result = resultFormatter(p[0] - p[1])
			case "mul":
				result = resultFormatter(p[0] * p[1])
			case "div":
				if p[1] == 0 {
					rpcErr = &RPCError{-32000, "Division by zero"}
				} else {
					result = resultFormatter(p[0] / p[1])
				}
			}
		}
	case "pre":
		var p []int
		if err := json.Unmarshal(req.Params, &p); err == nil && len(p) > 0 {
			precisionMutex.Lock()
			precision = p[0]
			precisionMutex.Unlock()
			log.Printf("Note: Precesion set to %d", p[0])
			result = "ok"
		}
	default:
		rpcErr = &RPCError{-32601, "Method not found"}
	}
	if req.Id == nil {
		return nil
	}

	return &JRPCResponse{JSONRPC: "2.0", ID: req.Id, Result: result, Error: rpcErr}
}

func httpHandler(w http.ResponseWriter, r *http.Request) {
	body, _ := io.ReadAll(r.Body)
	w.Header().Set("Content-Type", "application/json")

	if len(body) > 0 && body[0] == '[' {
		var reqs []JRPCRequest
		json.Unmarshal(body, &reqs)
		var resps []JRPCResponse

		for _, req := range reqs {
			if res := RPCHandler(req); res != nil {
				resps = append(resps, *res)
			}
		}

		if len(resps) > 0 {
			json.NewEncoder(w).Encode(resps)
		}

	} else {
		var req JRPCRequest
		if err := json.Unmarshal(body, &req); err != nil {
			log.Printf("Unmarshal error: %v", err)
			return
		}

		if res := RPCHandler(req); res != nil {
			json.NewEncoder(w).Encode(res)
		}
	}
}
func main() {
	router := mux.NewRouter()
	router.HandleFunc("/jrpc", httpHandler).Methods(http.MethodPost)

	port := ":3000"

	log.Printf("Server running at http://localhost%s", port)

	if err := http.ListenAndServe(port, router); err != nil {
		log.Print("Server failed to start")
	}
}
