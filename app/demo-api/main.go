package main

import (
	"os"

	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()

	r.GET("/api/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"app":            "k8s-multi-cloud",
			"version":        os.Getenv("VERSION"),
			"cloud_provider": os.Getenv("CLOUD_PROVIDER"),
		})
	})

	r.GET("/env/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"VERSION":        os.Getenv("VERSION"),
			"CLOUD_PROVIDER": os.Getenv("CLOUD_PROVIDER"),
		})
	})

	r.GET("/healthz", func(c *gin.Context) {
		c.String(200, "ok")
	})

	r.Run(":8080")
}
