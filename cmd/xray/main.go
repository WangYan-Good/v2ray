package main

import (
	"os"

	"github.com/WangYan-Good/xray/internal/app"
)

func main() {
	os.Exit(app.RunWithIO(os.Args[1:], os.Stdin, os.Stdout, os.Stderr))
}
