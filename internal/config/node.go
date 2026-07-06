package config

import (
	"fmt"
	"path/filepath"
	"strconv"
	"strings"
	"unicode"
)

const DefaultDirectAddress = "203.0.113.10"

type Node struct {
	Name            string
	FileName        string
	Protocol        string
	Port            int
	Listen          string
	ID              string
	Password        string
	Method          string
	Network         string
	Security        string
	Host            string
	Path            string
	ServiceName     string
	Flow            string
	ServerName      string
	Fingerprint     string
	PublicKey       string
	PrivateKey      string
	HeaderType      string
	AddressOverride string
}

func (n Node) Address() string {
	if strings.TrimSpace(n.AddressOverride) != "" {
		return strings.TrimSpace(n.AddressOverride)
	}
	if n.Host != "" {
		return n.Host
	}
	return DefaultDirectAddress
}

func (n Node) PublicPort() int {
	if n.Host != "" && (n.Network == "ws" || n.Network == "grpc" || n.Network == "xhttp" || n.Network == "h2") {
		return 443
	}
	return n.Port
}

func (n Node) DisplayPath() string {
	if n.Network == "grpc" {
		return n.ServiceName
	}
	return n.Path
}

func (n Node) UserValue() string {
	switch n.Protocol {
	case "trojan", "shadowsocks":
		return n.Password
	case "socks":
		if n.ID != "" {
			return n.ID
		}
		return n.Password
	default:
		return n.ID
	}
}

func (n Node) StringPort() string {
	return strconv.Itoa(n.Port)
}

func (n Node) PublicStringPort() string {
	return strconv.Itoa(n.PublicPort())
}

func InferName(path string) string {
	fileName := filepath.Base(path)
	return strings.TrimSuffix(fileName, filepath.Ext(fileName))
}

func inferHostFromName(name string) string {
	parts := strings.Split(name, "-")
	if len(parts) == 0 {
		return ""
	}
	last := strings.TrimSuffix(parts[len(parts)-1], ".json")
	if strings.Contains(last, ".") && !allDigits(last) {
		return last
	}
	return ""
}

func allDigits(value string) bool {
	if value == "" {
		return false
	}
	for _, r := range value {
		if !unicode.IsDigit(r) {
			return false
		}
	}
	return true
}

func (n Node) Validate() error {
	if n.Protocol == "" {
		return fmt.Errorf("%s: missing protocol", n.FileName)
	}
	if n.Port == 0 {
		return fmt.Errorf("%s: missing port", n.FileName)
	}
	return nil
}
