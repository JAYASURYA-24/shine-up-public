package services

import (
	"math"
	"testing"
	"github.com/stretchr/testify/assert"
)

func TestHaversine(t *testing.T) {
	// Points for testing
	// Gateway of India, Mumbai: 18.9220, 72.8347
	// Marine Drive, Mumbai: 18.9438, 72.8231
	// Geodatasource says approx 2.7 km

	lat1, lon1 := 18.9220, 72.8347
	lat2, lon2 := 18.9438, 72.8231

	dist := haversine(lat1, lon1, lat2, lon2)

	// Check if distance is reasonably close to 2.7km
	assert.True(t, math.Abs(dist-2.7) < 0.5, "Distance calculation should be accurate within 0.5km")

	// Same point should be zero
	assert.Equal(t, 0.0, haversine(lat1, lon1, lat1, lon1))
}

func TestGeofencingLogic(t *testing.T) {
	// Mock hub at specific location
	hubLat, hubLon := 19.0760, 72.8777 // Mumbai
	radius := 10.0 // 10km

	t.Run("Point Inside Radius", func(t *testing.T) {
		// Point approx 5km away
		testLat, testLon := 19.1000, 72.9000
		dist := haversine(testLat, testLon, hubLat, hubLon)
		assert.True(t, dist <= radius)
	})

	t.Run("Point Outside Radius", func(t *testing.T) {
		// Point approx 20km away
		testLat, testLon := 19.2000, 73.0000
		dist := haversine(testLat, testLon, hubLat, hubLon)
		assert.True(t, dist > radius)
	})
}

