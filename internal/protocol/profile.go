package protocol

import (
	"fmt"
	"sort"
	"strings"

	"github.com/WangYan-Good/xray/internal/config"
)

const (
	FixedHost          = "example.com"
	FixedUUID          = "11111111-1111-4111-8111-111111111111"
	FixedPath          = "/xray-test"
	FixedGRPCService   = "xray-grpc"
	FixedRealitySNI    = "www.microsoft.com"
	FixedRealityPubKey = "example-public-key"
	FixedRealityPriKey = "example-private-key"
	FixedPassword      = "example-password"
	FixedSocksUser     = "example-user"
	FixedSSMethod      = "aes-256-gcm"
)

type Profile struct {
	Key         string
	Name        string
	Protocol    string
	Port        int
	Listen      string
	ID          string
	Password    string
	Method      string
	Network     string
	Security    string
	Host        string
	Path        string
	ServiceName string
	Flow        string
	ServerName  string
	Fingerprint string
	PublicKey   string
	PrivateKey  string
	HeaderType  string
	XHTTPMode   string
	Address     string
}

func DefaultProfiles() []Profile {
	profiles := []Profile{
		{
			Key:         "vless-reality",
			Name:        "VLESS-XTLS-uTLS-REALITY-10001",
			Protocol:    "vless",
			Port:        10001,
			Listen:      "0.0.0.0",
			ID:          FixedUUID,
			Network:     "tcp",
			Security:    "reality",
			Flow:        "xtls-rprx-vision",
			ServerName:  FixedRealitySNI,
			Fingerprint: "ios",
			PublicKey:   FixedRealityPubKey,
			PrivateKey:  FixedRealityPriKey,
		},
		{
			Key:      "vless-ws-tls",
			Name:     "VLESS-WS-TLS-example.com",
			Protocol: "vless",
			Port:     10002,
			Listen:   "127.0.0.1",
			ID:       FixedUUID,
			Network:  "ws",
			Security: "tls",
			Host:     FixedHost,
			Path:     FixedPath,
		},
		{
			Key:         "vless-grpc-tls",
			Name:        "VLESS-gRPC-TLS-example.com",
			Protocol:    "vless",
			Port:        10003,
			Listen:      "127.0.0.1",
			ID:          FixedUUID,
			Network:     "grpc",
			Security:    "tls",
			Host:        FixedHost,
			ServiceName: FixedGRPCService,
		},
		{
			Key:       "vless-xhttp-tls",
			Name:      "VLESS-XHTTP-TLS-example.com",
			Protocol:  "vless",
			Port:      10004,
			Listen:    "127.0.0.1",
			ID:        FixedUUID,
			Network:   "xhttp",
			Security:  "tls",
			Host:      FixedHost,
			Path:      FixedPath,
			XHTTPMode: "auto",
		},
		{
			Key:       "trojan-xhttp-tls",
			Name:      "Trojan-XHTTP-TLS-example.com",
			Protocol:  "trojan",
			Port:      10005,
			Listen:    "127.0.0.1",
			Password:  FixedPassword,
			Network:   "xhttp",
			Security:  "tls",
			Host:      FixedHost,
			Path:      FixedPath,
			XHTTPMode: "auto",
		},
		{
			Key:        "vmess-tcp",
			Name:       "VMess-TCP-10006",
			Protocol:   "vmess",
			Port:       10006,
			Listen:     "0.0.0.0",
			ID:         FixedUUID,
			Network:    "tcp",
			HeaderType: "none",
		},
		{
			Key:      "vmess-ws-tls",
			Name:     "VMess-WS-TLS-example.com",
			Protocol: "vmess",
			Port:     10009,
			Listen:   "127.0.0.1",
			ID:       FixedUUID,
			Network:  "ws",
			Security: "tls",
			Host:     FixedHost,
			Path:     FixedPath,
		},
		{
			Key:      "trojan-ws-tls",
			Name:     "Trojan-WS-TLS-example.com",
			Protocol: "trojan",
			Port:     10010,
			Listen:   "127.0.0.1",
			Password: FixedPassword,
			Network:  "ws",
			Security: "tls",
			Host:     FixedHost,
			Path:     FixedPath,
		},
		{
			Key:      "shadowsocks",
			Name:     "Shadowsocks-10007",
			Protocol: "shadowsocks",
			Port:     10007,
			Listen:   "0.0.0.0",
			Password: FixedPassword,
			Method:   FixedSSMethod,
			Network:  "tcp,udp",
		},
		{
			Key:      "socks",
			Name:     "Socks-10008",
			Protocol: "socks",
			Port:     10008,
			Listen:   "0.0.0.0",
			ID:       FixedSocksUser,
			Password: FixedPassword,
			Network:  "tcp,udp",
		},
	}

	out := make([]Profile, len(profiles))
	copy(out, profiles)
	return out
}

func ProfileByName(name string) (Profile, error) {
	name = strings.ToLower(strings.TrimSpace(name))
	if name == "" {
		return Profile{}, fmt.Errorf("profile name required; candidates: %s", strings.Join(ProfileNames(), ", "))
	}

	for _, profile := range DefaultProfiles() {
		if strings.ToLower(profile.Key) == name || strings.ToLower(profile.Name) == name {
			return profile, nil
		}
	}

	var matches []Profile
	for _, profile := range DefaultProfiles() {
		if strings.Contains(strings.ToLower(profile.Key), name) || strings.Contains(strings.ToLower(profile.Name), name) {
			matches = append(matches, profile)
		}
	}

	switch len(matches) {
	case 1:
		return matches[0], nil
	case 0:
		return Profile{}, fmt.Errorf("profile not found: %s", name)
	default:
		names := make([]string, 0, len(matches))
		for _, profile := range matches {
			names = append(names, profile.Key)
		}
		sort.Strings(names)
		return Profile{}, fmt.Errorf("multiple profiles match %q: %s", name, strings.Join(names, ", "))
	}
}

func ProfileNames() []string {
	profiles := DefaultProfiles()
	names := make([]string, 0, len(profiles))
	for _, profile := range profiles {
		names = append(names, profile.Key)
	}
	sort.Strings(names)
	return names
}

func (p Profile) Node() config.Node {
	return config.Node{
		Name:            p.Name,
		FileName:        p.Key + ".json",
		Protocol:        p.Protocol,
		Port:            p.Port,
		Listen:          p.Listen,
		ID:              p.ID,
		Password:        p.Password,
		Method:          p.Method,
		Network:         p.Network,
		Security:        p.Security,
		Host:            p.Host,
		Path:            p.Path,
		ServiceName:     p.ServiceName,
		Flow:            p.Flow,
		ServerName:      p.ServerName,
		Fingerprint:     valueOr(p.Fingerprint, "ios"),
		PublicKey:       p.PublicKey,
		PrivateKey:      p.PrivateKey,
		HeaderType:      p.HeaderType,
		AddressOverride: p.Address,
	}
}

func ProfileFromNode(node config.Node) Profile {
	key := strings.TrimSuffix(strings.ToLower(node.FileName), ".json")
	if key == "" {
		key = strings.ToLower(strings.ReplaceAll(node.Name, " ", "-"))
	}
	security := node.Security
	if node.Host != "" && security != "reality" {
		switch node.Network {
		case "ws", "grpc", "xhttp", "h2":
			security = "tls"
		}
	}
	return Profile{
		Key:         key,
		Name:        node.Name,
		Protocol:    node.Protocol,
		Port:        node.Port,
		Listen:      valueOr(node.Listen, "0.0.0.0"),
		ID:          node.ID,
		Password:    node.Password,
		Method:      node.Method,
		Network:     node.Network,
		Security:    security,
		Host:        node.Host,
		Path:        node.Path,
		ServiceName: node.ServiceName,
		Flow:        node.Flow,
		ServerName:  node.ServerName,
		Fingerprint: valueOr(node.Fingerprint, "ios"),
		PublicKey:   node.PublicKey,
		PrivateKey:  valueOr(node.PrivateKey, "unknown-private-key"),
		HeaderType:  node.HeaderType,
		XHTTPMode:   "auto",
		Address:     node.AddressOverride,
	}
}

func (p Profile) Validate() error {
	if p.Key == "" {
		return fmt.Errorf("missing profile key")
	}
	if p.Name == "" {
		return fmt.Errorf("%s: missing profile name", p.Key)
	}
	if p.Protocol == "" {
		return fmt.Errorf("%s: missing protocol", p.Key)
	}
	if p.Port == 0 {
		return fmt.Errorf("%s: missing port", p.Key)
	}
	if p.Listen == "" {
		return fmt.Errorf("%s: missing listen", p.Key)
	}

	switch p.Protocol {
	case "vless", "vmess":
		if p.ID == "" {
			return fmt.Errorf("%s: missing uuid", p.Key)
		}
	case "trojan":
		if p.Password == "" {
			return fmt.Errorf("%s: missing password", p.Key)
		}
	case "shadowsocks":
		if p.Method == "" || p.Password == "" {
			return fmt.Errorf("%s: missing shadowsocks method or password", p.Key)
		}
	case "socks":
		if p.ID == "" || p.Password == "" {
			return fmt.Errorf("%s: missing socks credentials", p.Key)
		}
	default:
		return fmt.Errorf("%s: unsupported protocol: %s", p.Key, p.Protocol)
	}

	if p.Security == "reality" {
		if p.ServerName == "" || p.PrivateKey == "" || p.PublicKey == "" {
			return fmt.Errorf("%s: missing reality settings", p.Key)
		}
	}
	if p.Network == "ws" && p.Path == "" {
		return fmt.Errorf("%s: missing ws path", p.Key)
	}
	if p.Network == "grpc" && p.ServiceName == "" {
		return fmt.Errorf("%s: missing grpc serviceName", p.Key)
	}
	if p.Network == "xhttp" && (p.Host == "" || p.Path == "") {
		return fmt.Errorf("%s: missing xhttp host or path", p.Key)
	}
	return nil
}

func (p Profile) xrayTag() string {
	return p.Name + ".json"
}

func (p Profile) xraySecurity() string {
	if p.Security == "reality" {
		return "reality"
	}
	if p.Host != "" && (p.Protocol == "vless" || p.Protocol == "trojan") {
		return "none"
	}
	return p.Security
}

func (p Profile) xhttpMode() string {
	return valueOr(p.XHTTPMode, "auto")
}
