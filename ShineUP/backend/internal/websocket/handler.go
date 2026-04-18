package websocket

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	ws "github.com/gorilla/websocket"
)

var upgrader = ws.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for development
	},
}

// ChatMessageCallback is called when a client sends a chat message via WebSocket
type ChatMessageCallback func(senderID uuid.UUID, senderRole string, payload json.RawMessage)

// WSHandler handles WebSocket upgrade requests
type WSHandler struct {
	Hub           *Hub
	JWTSecret     string
	OnChatMessage ChatMessageCallback
}

// NewWSHandler creates a new WebSocket handler
func NewWSHandler(hub *Hub, jwtSecret string) *WSHandler {
	return &WSHandler{
		Hub:       hub,
		JWTSecret: jwtSecret,
	}
}

// HandleWebSocket upgrades the HTTP connection to WebSocket
func (h *WSHandler) HandleWebSocket(c *gin.Context) {
	// Authenticate via JWT in query parameter
	tokenStr := c.Query("token")
	if tokenStr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing token query parameter"})
		return
	}

	// Parse and validate JWT
	token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
		return []byte(h.JWTSecret), nil
	})
	if err != nil || !token.Valid {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid or expired token"})
		return
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token claims"})
		return
	}

	userIDStr, _ := claims["user_id"].(string)
	role, _ := claims["role"].(string)

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user_id in token"})
		return
	}

	// Upgrade to WebSocket
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WS Upgrade Error: %v", err)
		return
	}

	// Create client and register
	client := &Client{
		Hub:    h.Hub,
		Conn:   conn,
		Send:   make(chan []byte, 256),
		UserID: userID,
		Role:   role,
	}

	h.Hub.register <- client

	// Send welcome message
	welcome := WSMessage{
		Type: "CONNECTED",
		Payload: map[string]interface{}{
			"user_id": userID.String(),
			"role":    role,
			"message": "Connected to Shine-Up real-time service",
		},
		Time: time.Now(),
	}
	data, _ := json.Marshal(welcome)
	client.Send <- data

	// Start read/write pumps
	go client.WritePump()
	go client.ReadPump(func(c *Client, message []byte) {
		// Parse incoming message
		var incoming struct {
			Type    string          `json:"type"`
			Payload json.RawMessage `json:"payload"`
		}
		if err := json.Unmarshal(message, &incoming); err != nil {
			log.Printf("WS: Invalid message format from user %s: %v", c.UserID, err)
			return
		}

		// Handle chat messages
		if incoming.Type == "CHAT_MESSAGE" && h.OnChatMessage != nil {
			h.OnChatMessage(c.UserID, c.Role, incoming.Payload)
		}
	})
}
