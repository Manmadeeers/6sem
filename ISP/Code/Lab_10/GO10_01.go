package main

import (
	"errors"
	"fmt"
	"log"
	"net/http"

	"github.com/graphql-go/graphql"
	"github.com/graphql-go/handler"
	"github.com/jackc/pgx/v5/pgconn"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var db *gorm.DB

type Celebrity struct {
	Id int `gorm:"primaryKey;column:id"`

	FullName string `gorm:"column:fullname"`

	Nationality string `gorm:"column:nationality"`

	ReqPhotoPath string `gorm:"column:reqphotopath"`
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

func buildSchema() (graphql.Schema, error) {
	celebrityType := graphql.NewObject(graphql.ObjectConfig{
		Name: "Celebrity",
		Fields: graphql.Fields{
			"Id":           &graphql.Field{Type: graphql.Int},
			"FullName":     &graphql.Field{Type: graphql.String},
			"Nationality":  &graphql.Field{Type: graphql.String},
			"ReqPhotoPath": &graphql.Field{Type: graphql.String},
		},
	})

	queryType := graphql.NewObject(graphql.ObjectConfig{
		Name: "Query",
		Fields: graphql.Fields{
			"allCelebrities": &graphql.Field{
				Type: graphql.NewList(celebrityType),
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					var celebrities []Celebrity
					if err := db.Find(&celebrities).Error; err != nil {
						log.Printf("Failed to get all celebrities: %v", err)
						return nil, errors.New("failed to get the complete list of data")
					}
					return celebrities, nil
				},
			},
			"celebrityById": &graphql.Field{
				Type: celebrityType,
				Args: graphql.FieldConfigArgument{
					"id": &graphql.ArgumentConfig{Type: graphql.NewNonNull(graphql.Int)},
				},
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					id := p.Args["id"].(int)
					var c Celebrity
					if err := db.First(&c, id).Error; err != nil {
						log.Printf("Failed to get a celebrity by id: %v", err)
						if errors.Is(err, gorm.ErrRecordNotFound) {
							return nil, errors.New("celebrity with this ID could not be found")
						}
						return nil, errors.New("failed to get a celebrity by id")
					}
					return c, nil
				},
			},
		},
	})

	mutationType := graphql.NewObject(graphql.ObjectConfig{
		Name: "Mutation",
		Fields: graphql.Fields{
			"addCelebrity": &graphql.Field{
				Type: celebrityType,
				Args: graphql.FieldConfigArgument{
					"id":           &graphql.ArgumentConfig{Type: graphql.Int},
					"fullName":     &graphql.ArgumentConfig{Type: graphql.String},
					"nationality":  &graphql.ArgumentConfig{Type: graphql.String},
					"reqPhotoPath": &graphql.ArgumentConfig{Type: graphql.String},
				},
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					newCelebrity := Celebrity{}
					if id, ok := p.Args["id"].(int); ok {
						newCelebrity.Id = id
					}
					if fullName, ok := p.Args["fullName"].(string); ok {
						newCelebrity.FullName = fullName
					}
					if nationality, ok := p.Args["nationality"].(string); ok {
						newCelebrity.Nationality = nationality
					}
					if reqPhotoPath, ok := p.Args["reqPhotoPath"].(string); ok {
						newCelebrity.ReqPhotoPath = reqPhotoPath
					}

					result := db.Create(&newCelebrity)
					if result.Error != nil {
						log.Printf("Failed to add a new celebrity: %v", result.Error)
						if pgErr, ok := result.Error.(*pgconn.PgError); ok && pgErr.Code == "23505" {
							return nil, errors.New("celebrity with this id already exists")
						}
						return nil, errors.New("failed to add a new celebrity")
					}

					return newCelebrity, nil
				},
			},
			"updateCelebrity": &graphql.Field{
				Type: celebrityType,
				Args: graphql.FieldConfigArgument{
					"id":           &graphql.ArgumentConfig{Type: graphql.NewNonNull(graphql.Int)},
					"fullName":     &graphql.ArgumentConfig{Type: graphql.String},
					"nationality":  &graphql.ArgumentConfig{Type: graphql.String},
					"reqPhotoPath": &graphql.ArgumentConfig{Type: graphql.String},
				},
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					id := p.Args["id"].(int)

					var celebrity Celebrity
					if err := db.First(&celebrity, id).Error; err != nil {
						log.Printf("Element to update not found: %v", err)
						return nil, errors.New("element to update not found")
					}

					if fullName, ok := p.Args["fullName"].(string); ok {
						celebrity.FullName = fullName
					}
					if nationality, ok := p.Args["nationality"].(string); ok {
						celebrity.Nationality = nationality
					}
					if reqPhotoPath, ok := p.Args["reqPhotoPath"].(string); ok {
						celebrity.ReqPhotoPath = reqPhotoPath
					}

					if err := db.Save(&celebrity).Error; err != nil {
						log.Printf("Failed to update celebrity: %v", err)
						return nil, errors.New("failed to update celebrity")
					}

					return celebrity, nil
				},
			},
			"deleteCelebrity": &graphql.Field{
				Type: graphql.Boolean,
				Args: graphql.FieldConfigArgument{
					"id": &graphql.ArgumentConfig{Type: graphql.NewNonNull(graphql.Int)},
				},
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					id := p.Args["id"].(int)
					result := db.Delete(&Celebrity{}, id)
					if result.RowsAffected == 0 {
						log.Print("Element to delete not found")
						return false, errors.New("element to delete not found")
					}
					if result.Error != nil {
						log.Printf("Failed to delete celebrity: %v", result.Error)
						return false, errors.New("failed to delete celebrity")
					}
					return true, nil
				},
			},
		},
	})

	return graphql.NewSchema(graphql.SchemaConfig{
		Query:    queryType,
		Mutation: mutationType,
	})
}

func main() {
	initDB()

	schema, err := buildSchema()
	if err != nil {
		log.Fatalf("Failed to build schema: %v", err)
	}

	graphqlHandler := handler.New(&handler.Config{
		Schema:   &schema,
		Pretty:   true,
		GraphiQL: true,
	})

	http.Handle("/graphql", graphqlHandler)

	port := ":3000"
	log.Printf("Server running at http://localhost%s/graphql", port)

	if err := http.ListenAndServe(port, nil); err != nil {
		log.Print("Server failed to start")
	}
}
