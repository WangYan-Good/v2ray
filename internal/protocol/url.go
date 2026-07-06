package protocol

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/url"
	"strconv"
	"strings"

	"github.com/WangYan-Good/xray/internal/config"
)

func ShareURL(node config.Node) (string, error) {
	switch node.Protocol {
	case "vmess":
		return vmessURL(node)
	case "vless":
		return vlessURL(node), nil
	case "trojan":
		return trojanURL(node), nil
	case "shadowsocks":
		return shadowsocksURL(node), nil
	case "socks":
		return socksURL(node), nil
	default:
		return "", fmt.Errorf("unsupported protocol: %s", node.Protocol)
	}
}

func vmessURL(node config.Node) (string, error) {
	payload := map[string]string{
		"v":    "2",
		"ps":   node.Name,
		"add":  node.Address(),
		"port": node.PublicStringPort(),
		"id":   node.ID,
		"aid":  "0",
		"net":  node.Network,
		"type": node.HeaderType,
		"path": node.Path,
	}
	if node.Host != "" {
		payload["host"] = node.Host
		payload["tls"] = "tls"
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	return "vmess://" + base64.StdEncoding.EncodeToString(data), nil
}

func vlessURL(node config.Node) string {
	values := url.Values{}
	values.Set("encryption", "none")
	if node.Security == "reality" {
		values.Set("security", "reality")
		values.Set("flow", valueOr(node.Flow, "xtls-rprx-vision"))
		values.Set("type", "tcp")
		values.Set("sni", node.ServerName)
		values.Set("pbk", node.PublicKey)
		values.Set("fp", valueOr(node.Fingerprint, "ios"))
	} else {
		values.Set("security", "tls")
		values.Set("type", node.Network)
		if node.Host != "" {
			values.Set("host", node.Host)
		}
		setPathValue(values, node)
	}
	return fmt.Sprintf("vless://%s@%s:%d?%s#%s", node.ID, node.Address(), node.PublicPort(), values.Encode(), url.QueryEscape(node.Name))
}

func trojanURL(node config.Node) string {
	values := url.Values{}
	values.Set("security", "tls")
	values.Set("type", node.Network)
	if node.Host != "" {
		values.Set("host", node.Host)
		values.Set("sni", node.Host)
	}
	setPathValue(values, node)
	return fmt.Sprintf("trojan://%s@%s:%d?%s#%s", url.QueryEscape(node.Password), node.Address(), node.PublicPort(), values.Encode(), url.QueryEscape(node.Name))
}

func shadowsocksURL(node config.Node) string {
	return fmt.Sprintf("ss://%s:%s@%s:%d#%s", url.QueryEscape(node.Method), url.QueryEscape(node.Password), node.Address(), node.PublicPort(), url.QueryEscape(node.Name))
}

func socksURL(node config.Node) string {
	credential := base64.StdEncoding.EncodeToString([]byte(node.ID + ":" + node.Password))
	return fmt.Sprintf("socks://%s@%s:%d#%s", credential, node.Address(), node.PublicPort(), url.QueryEscape(node.Name))
}

func setPathValue(values url.Values, node config.Node) {
	switch node.Network {
	case "grpc":
		if node.ServiceName != "" {
			values.Set("serviceName", node.ServiceName)
		}
	default:
		if node.Path != "" {
			values.Set("path", node.Path)
		}
	}
}

func valueOr(value, fallback string) string {
	if strings.TrimSpace(value) == "" {
		return fallback
	}
	return value
}

func QueryHas(rawURL, key, expected string) bool {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return false
	}
	return parsed.Query().Get(key) == expected
}

func PortString(node config.Node) string {
	return strconv.Itoa(node.PublicPort())
}
