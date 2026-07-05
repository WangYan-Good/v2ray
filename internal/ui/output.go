package ui

import (
	"fmt"
	"io"
	"os"

	"github.com/WangYan-Good/xray/internal/config"
)

func Version(out io.Writer, confDir string) {
	fmt.Fprintln(out, "xray go-cli dev")
	fmt.Fprintf(out, "conf_dir = %s\n", confDir)
}

func Status(out io.Writer, confDir, configPath string, nodes []config.Node) {
	fmt.Fprintf(out, "conf_dir = %s\n", confDir)
	fmt.Fprintf(out, "conf_dir_exists = %t\n", pathExists(confDir))
	fmt.Fprintf(out, "config = %s\n", configPath)
	fmt.Fprintf(out, "config_exists = %t\n", pathExists(configPath))
	fmt.Fprintf(out, "node_count = %d\n", len(nodes))
}

func Info(out io.Writer, node config.Node) {
	fmt.Fprintf(out, "name = %s\n", node.Name)
	fmt.Fprintf(out, "file = %s\n", node.FileName)
	fmt.Fprintf(out, "protocol = %s\n", node.Protocol)
	fmt.Fprintf(out, "address = %s\n", node.Address())
	fmt.Fprintf(out, "port = %d\n", node.PublicPort())
	printIf(out, "id", node.ID)
	printIf(out, "password", node.Password)
	printIf(out, "method", node.Method)
	printIf(out, "network", node.Network)
	if node.Host != "" {
		fmt.Fprintf(out, "host = %s\n", node.Host)
	}
	printIf(out, "path", node.Path)
	printIf(out, "serviceName", node.ServiceName)
	if node.Host != "" {
		fmt.Fprintln(out, "security = tls")
	} else {
		printIf(out, "security", node.Security)
	}
	printIf(out, "flow", node.Flow)
	printIf(out, "serverName", node.ServerName)
	printIf(out, "fingerprint", node.Fingerprint)
	printIf(out, "publicKey", node.PublicKey)
}

func printIf(out io.Writer, key, value string) {
	if value != "" {
		fmt.Fprintf(out, "%s = %s\n", key, value)
	}
}

func pathExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
