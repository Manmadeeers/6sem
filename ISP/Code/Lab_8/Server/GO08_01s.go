package main

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func wsHandler(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		fmt.Println("Error upgrading connection: ", err)
		return
	}
	defer conn.Close()

	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			fmt.Println("Error reading a message: ", err)
			break
		}
		fmt.Printf("Received: %s \n", message)
		if err := conn.WriteMessage(websocket.TextMessage, []byte(strings.Join([]string{"From server", string(message)}, ""))); err != nil {
			fmt.Println("Error writing a message: ", err)
			break
		}
	}
}
func main() {
	http.HandleFunc("/ws", wsHandler)

	fmt.Println("Websocker server started at port 4000")
	err := http.ListenAndServe(":4000", nil)
	if err != nil {
		fmt.Println("Error starting server: ", err)
	}
}
