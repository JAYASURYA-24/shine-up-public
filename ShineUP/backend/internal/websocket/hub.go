package websocket

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/google/uuid"
	ws "github.com/gorilla/websocket"
)

// ─── WebSocket Message ───────────────────────────────────
type WSMessage struct {
	Type    string      `json:"type"`
	Payload interface{} `json:"payload"`
	Time    time.Time   `json:"time"`
}

// ─── Client ──────────────────────────────────────────────
type Client struct {
	Hub    *Hub
	Conn   *ws.Conn
	Send   chan []byte
	UserID uuid.UUID
	Role   string // CUSTOMER, PARTNER, ADMIN
}

// ─── Hub ─────────────────────────────────────────────────
type Hub struct {
	// Map of userID -> set of clients (a user can have multiple connections)
	clients    map[uuid.UUID]map[*Client]bool
	register   chan *Client
	unregister chan *Client
	broadcast  chan []byte // broadcast to ALL connected clients
	mu         sync.RWMutex
}

// NewHub creates a new WebSocket hub
func NewHub() *Hub {
	return &Hub{
		clients:    make(map[uuid.UUID]map[*Client]bool),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan []byte, 256),
	}
}

// Run starts the hub's event loop
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			if h.clients[client.UserID] == nil {
				h.clients[client.UserID] = make(map[*Client]bool)
			}
			h.clients[client.UserID][client] = true
			h.mu.Unlock()
			log.Printf("🔌 WS: User %s connected (role: %s). Total connections for user: %d",
				client.UserID, client.Role, len(h.clients[client.UserID]))

		case client := <-h.unregister:
			h.mu.Lock()
			if conns, ok := h.clients[client.UserID]; ok {
				if _, exists := conns[client]; exists {
					delete(conns, client)
					close(client.Send)
					if len(conns) == 0 {
						delete(h.clients, client.UserID)
					}
				}
			}
			h.mu.Unlock()
			log.Printf("🔌 WS: User %s disconnected (role: %s)", client.UserID, client.Role)

		case message := <-h.broadcast:
			h.mu.RLock()
			for _, conns := range h.clients {
				for client := range conns {
					select {
					case client.Send <- message:
					default:
						close(client.Send)
						delete(conns, client)
					}
				}
			}
			h.mu.RUnlock()
		}
	}
}

// BroadcastToUser sends a message to all connections of a specific user
func (h *Hub) BroadcastToUser(userID uuid.UUID, msg WSMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("WS: Error marshaling message for user %s: %v", userID, err)
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()

	if conns, ok := h.clients[userID]; ok {
		for client := range conns {
			select {
			case client.Send <- data:
			default:
				close(client.Send)
				delete(conns, client)
			}
		}
	}
}

// BroadcastToRole sends a message to all users with a specific role
func (h *Hub) BroadcastToRole(role string, msg WSMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("WS: Error marshaling role broadcast: %v", err)
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()

	for _, conns := range h.clients {
		for client := range conns {
			if client.Role == role {
				select {
				case client.Send <- data:
				default:
					close(client.Send)
					delete(conns, client)
				}
			}
		}
	}
}

// BroadcastToAll sends a message to every connected client
func (h *Hub) BroadcastToAll(msg WSMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("WS: Error marshaling broadcast: %v", err)
		return
	}

	h.broadcast <- data
}

// GetConnectionCount returns the total number of active connections
func (h *Hub) GetConnectionCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	count := 0
	for _, conns := range h.clients {
		count += len(conns)
	}
	return count
}

// GetUserCount returns the number of unique connected users
func (h *Hub) GetUserCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

// ─── Client Read/Write Pumps ─────────────────────────────

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 4096
)

// ReadPump reads messages from the WebSocket connection
func (c *Client) ReadPump(onMessage func(client *Client, message []byte)) {
	defer func() {
		c.Hub.unregister <- c
		c.Conn.Close()
	}()

	c.Conn.SetReadLimit(maxMessageSize)
	c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error {
		c.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			if ws.IsUnexpectedCloseError(err, ws.CloseGoingAway, ws.CloseAbnormalClosure) {
				log.Printf("WS Read Error: %v", err)
			}
			break
		}
		if onMessage != nil {
			onMessage(c, message)
		}
	}
}

// WritePump writes messages to the WebSocket connection
func (c *Client) WritePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.Send:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.Conn.WriteMessage(ws.CloseMessage, []byte{})
				return
			}

			w, err := c.Conn.NextWriter(ws.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// Drain queued messages
			n := len(c.Send)
			for i := 0; i < n; i++ {
				w.Write([]byte("\n"))
				w.Write(<-c.Send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.Conn.WriteMessage(ws.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
