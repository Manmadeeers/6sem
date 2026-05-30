package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
)

type Celebrity struct {
	Id int `json:"id"`

	FullName string `json:"FullName"`

	Nationality string `json:"Nationality"`

	ReqPhotoPath string `json:"ReqPhotoPath"`
}

var db *sql.DB

const openAPISpec = `{
  "openapi": "3.0.3",
  "info": {
    "title": "Celebrities REST API",
    "version": "1.0.0",
    "description": "CRUD API for celebrities backed by PostgreSQL"
  },
  "servers": [
    {
      "url": "http://localhost:3000"
    }
  ],
  "paths": {
    "/Celebrities/All": {
      "get": {
        "summary": "Get all celebrities",
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/Celebrity"
                  }
                }
              }
            }
          }
        }
      }
    },
    "/Celebrities": {
      "post": {
        "summary": "Create celebrity",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/Celebrity"
              }
            }
          }
        },
        "responses": {
          "201": {
            "description": "Created",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Celebrity"
                }
              }
            }
          }
        }
      }
    },
    "/Celebrities/{id}": {
      "get": {
        "summary": "Get celebrity by id",
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "integer"
            }
          }
        ],
        "responses": {
          "200": {
          
            "description": "OK",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Celebrity"
                }
              }
            }
          },
          "404": {
            "description": "Not found"
          }
        }
      },
      "put": {
        "summary": "Update celebrity",
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "integer"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/Celebrity"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Celebrity"
                }
              }
            }
          },
          "404": {
            "description": "Not found"
          }
        }
      },
      "delete": {
        "summary": "Delete celebrity",
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "integer"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Deleted"
          },
          "404": {
            "description": "Not found"
          }
        }
      }
    }
  },
  "components": {
    "schemas": {
      "Celebrity": {
        "type": "object",
        "properties": {
          "id": {
            "type": "integer"
          },
          "FullName": {
            "type": "string"
          },
          "Nationality": {
            "type": "string"
          },
          "ReqPhotoPath": {
            "type": "string"
          }
        }
      }
    }
  }
}`

const swaggerUIHTML = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Celebrities API Docs</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css" />
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-standalone-preset.js"></script>
  <script>
    window.onload = function() {
      SwaggerUIBundle({
        url: '/openapi.json',
        dom_id: '#swagger-ui',
        presets: [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset],
        layout: 'StandaloneLayout'
      });
    };
  </script>
</body>
</html>`

func initDB() {
	connStr := "user=postgres password=pass dbname=celebrities_db sslmode=disable"

	var err error
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatal("Failed to open a database: ", err)
	}

	err = db.Ping()
	if err != nil {
		log.Fatal("Failed to connect to a database: ", err)
	}

	fmt.Println("Connection sucessfull")
}

func GetAllCelebritiesHandler(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("select id, fullname,nationality, reqphotopath from Celebrities")
	if err != nil {
		log.Printf("Query failed: %v", err)
		http.Error(w, "Select query to Celebrities table failed", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var celebrities []Celebrity
	for rows.Next() {
		var c Celebrity
		if err := rows.Scan(&c.Id, &c.FullName, &c.Nationality, &c.ReqPhotoPath); err != nil {
			log.Printf("Failed to scan a query row: %v", err)
			continue
		}
		celebrities = append(celebrities, c)
	}

	if celebrities == nil {
		celebrities = []Celebrity{}
	}

	w.Header().Set("Content-type", "application/json")
	json.NewEncoder(w).Encode(celebrities)
}

func GetCelebrityByIdHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	idStr := vars["id"]

	var c Celebrity

	queryStatement := "Select * from Celebrities where id=$1"
	err := db.QueryRow(queryStatement, idStr).Scan(&c.Id, &c.FullName, &c.Nationality, &c.ReqPhotoPath)
	if err != nil {
		if err == sql.ErrNoRows {
			http.Error(w, "Celebirty with this id not found", http.StatusNotFound)
			log.Printf("Celebrity with this id not found: %v", err)
			return
		}
		log.Printf("Failed to select a celebrity by id: %v", err)
		http.Error(w, "Failed to select a celebrityb by id", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-type", "application/json")
	json.NewEncoder(w).Encode(c)
}

func AddCelebrityHandler(w http.ResponseWriter, r *http.Request) {
	var newCelebrity Celebrity

	err := json.NewDecoder(r.Body).Decode(&newCelebrity)
	if err != nil {
		log.Printf("Failed to decode request body: %v", err)
		http.Error(w, "Failed to decode request body", http.StatusBadRequest)
		return
	}

	queryStatement := "Insert into Celebrities(Id, FullName, Nationality, ReqPhotoPath) values ($1,$2,$3,$4) returning Id"
	err = db.QueryRow(queryStatement, newCelebrity.Id, newCelebrity.FullName, newCelebrity.Nationality, newCelebrity.ReqPhotoPath).Scan(&newCelebrity.Id)
	if err != nil {
		log.Printf("Failed to insert a new celebrity: %v", err)
		http.Error(w, "Failed to insert a new Celebrity", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(newCelebrity)
}

func UpdateCelebrityHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	idStr := vars["id"]

	var updatedCelebrity Celebrity
	err := json.NewDecoder(r.Body).Decode(&updatedCelebrity)
	if err != nil {
		log.Printf("Failed to decode request body: %v", err)
		http.Error(w, "Failed to decode request body", http.StatusBadRequest)
		return
	}

	queryStatement := "Update Celebrities set FullName=$1, Nationality=$2, ReqPhotoPath=$3 Where Id=$4"

	result, err := db.Exec(queryStatement, updatedCelebrity.FullName, updatedCelebrity.Nationality, updatedCelebrity.ReqPhotoPath, idStr)
	if err != nil {
		log.Printf("Failed to update a celebrity: %v", err)
		http.Error(w, "Failed to update a celebrity", http.StatusInternalServerError)
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		log.Printf("No rows were affected during update operation")
		http.Error(w, "Celebrity not found", http.StatusNotFound)
		return
	}
	updatedCelebrity.Id, _ = strconv.Atoi(idStr)
	w.Header().Set("Content-type", "application/json")
	json.NewEncoder(w).Encode(updatedCelebrity)
}

func DeleteCelebrityHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	idStr := vars["id"]

	queryStatement := "Delete from Celebrities where Id=$1"

	result, err := db.Exec(queryStatement, idStr)
	if err != nil {
		log.Printf("Failed to delete a celebrity: %v", err)
		http.Error(w, "Failed to delete a celebrity", http.StatusInternalServerError)
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		log.Printf("Now rows were afected during Delete operation")
		http.Error(w, "Celebrity not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": fmt.Sprintf("Celebrity with ID %s successfully deleted", idStr)})
}

func OpenAPISpecHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(openAPISpec))
}

func SwaggerUIHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(swaggerUIHTML))
}

func main() {
	initDB()
	defer db.Close()

	router := mux.NewRouter()

	router.HandleFunc("/Celebrities/All", GetAllCelebritiesHandler).Methods(http.MethodGet)
	router.HandleFunc("/Celebrities/{id:[0-9]+}", GetCelebrityByIdHandler).Methods(http.MethodGet)
	router.HandleFunc("/Celebrities", AddCelebrityHandler).Methods(http.MethodPost)
	router.HandleFunc("/Celebrities/{id:[0-9]+}", UpdateCelebrityHandler).Methods(http.MethodPut)
	router.HandleFunc("/Celebrities/{id:[0-9]+}", DeleteCelebrityHandler).Methods(http.MethodDelete)

	router.HandleFunc("/openapi.json", OpenAPISpecHandler).Methods(http.MethodGet)
	router.HandleFunc("/docs", SwaggerUIHandler).Methods(http.MethodGet)
	router.HandleFunc("/docs/", SwaggerUIHandler).Methods(http.MethodGet)

	port := "3000"
	log.Printf("Server running at http://localhost:%s", port)
	log.Printf("OpenAPI UI: http://localhost:%s/docs", port)

	if err := http.ListenAndServe(":"+port, router); err != nil {
		log.Printf("Server failed: %v", err)
	}
}
