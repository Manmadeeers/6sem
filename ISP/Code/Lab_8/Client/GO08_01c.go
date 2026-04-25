package main

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"time"

	"github.com/gorilla/websocket"
)

func main() {
	url := "ws://localhost:4000/ws"

	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		log.Fatal("Dial error: %v", err)

	}
	defer conn.Close()

	go func() {
		for {
			_, msg, err := conn.ReadMessage()
			if err != nil {
				log.Printf("Read error: %v", err)
				return
			}

			log.Printf("Server replied: %s", msg)
		}
	}()

	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	interrupt := make(chan os.Signal, 1)
	signal.Notify(interrupt, os.Interrupt)

	i := 1

	for {
		select {
		case <-ticker.C:
			text := fmt.Sprintf(" message #%d", i)
			if err := conn.WriteMessage(websocket.TextMessage, []byte(text)); err != nil {
				log.Printf("write error: %v", err)
				return
			}
			log.Printf("sent: %s", text)
			i++

		case <-interrupt:
			log.Println("interrupt received, closing")
			_ = conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseNormalClosure, "bye"))
			return
		}
	}

}
