package protocol

import (
	"encoding/json"
	"fmt"
)

type generatedXrayConfig struct {
	Inbounds []generatedInbound `json:"inbounds"`
}

type generatedInbound struct {
	Tag            string                   `json:"tag"`
	Port           int                      `json:"port"`
	Listen         string                   `json:"listen"`
	Protocol       string                   `json:"protocol"`
	Settings       map[string]any           `json:"settings"`
	StreamSettings *generatedStreamSettings `json:"streamSettings,omitempty"`
}

type generatedStreamSettings struct {
	Network         string                    `json:"network,omitempty"`
	Security        string                    `json:"security,omitempty"`
	WSSettings      *generatedWSSettings      `json:"wsSettings,omitempty"`
	GRPCSettings    *generatedGRPCSettings    `json:"grpcSettings,omitempty"`
	XHTTPSettings   *generatedXHTTPSettings   `json:"xhttpSettings,omitempty"`
	RealitySettings *generatedRealitySettings `json:"realitySettings,omitempty"`
	TCPSettings     *generatedTCPSettings     `json:"tcpSettings,omitempty"`
}

type generatedWSSettings struct {
	Path    string            `json:"path"`
	Headers map[string]string `json:"headers,omitempty"`
}

type generatedGRPCSettings struct {
	ServiceName string `json:"serviceName"`
}

type generatedXHTTPSettings struct {
	Host string `json:"host"`
	Path string `json:"path"`
	Mode string `json:"mode"`
}

type generatedRealitySettings struct {
	Show        bool     `json:"show"`
	Dest        string   `json:"dest"`
	Xver        int      `json:"xver"`
	ServerNames []string `json:"serverNames"`
	PrivateKey  string   `json:"privateKey"`
	PublicKey   string   `json:"publicKey"`
	ShortIDs    []string `json:"shortIds"`
}

type generatedTCPSettings struct {
	Header generatedTCPHeader `json:"header"`
}

type generatedTCPHeader struct {
	Type string `json:"type"`
}

func XrayJSON(profile Profile) ([]byte, error) {
	if err := profile.Validate(); err != nil {
		return nil, err
	}

	inbound := generatedInbound{
		Tag:            profile.xrayTag(),
		Port:           profile.Port,
		Listen:         profile.Listen,
		Protocol:       profile.Protocol,
		Settings:       xraySettings(profile),
		StreamSettings: xrayStreamSettings(profile),
	}
	out := generatedXrayConfig{Inbounds: []generatedInbound{inbound}}
	return json.MarshalIndent(out, "", "  ")
}

func xraySettings(profile Profile) map[string]any {
	switch profile.Protocol {
	case "vless":
		client := map[string]any{"id": profile.ID}
		if profile.Flow != "" {
			client["flow"] = profile.Flow
		}
		return map[string]any{
			"clients":    []map[string]any{client},
			"decryption": "none",
		}
	case "vmess":
		return map[string]any{
			"clients": []map[string]any{{
				"id":      profile.ID,
				"alterId": 0,
			}},
		}
	case "trojan":
		return map[string]any{
			"clients": []map[string]any{{
				"password": profile.Password,
			}},
		}
	case "shadowsocks":
		return map[string]any{
			"method":   profile.Method,
			"password": profile.Password,
			"network":  valueOr(profile.Network, "tcp,udp"),
		}
	case "socks":
		return map[string]any{
			"auth": "password",
			"accounts": []map[string]any{{
				"user": profile.ID,
				"pass": profile.Password,
			}},
			"udp": true,
		}
	default:
		return map[string]any{}
	}
}

func xrayStreamSettings(profile Profile) *generatedStreamSettings {
	if profile.Protocol == "shadowsocks" || profile.Protocol == "socks" {
		return nil
	}

	settings := &generatedStreamSettings{
		Network:  profile.Network,
		Security: profile.xraySecurity(),
	}
	if settings.Security == "" && (profile.Protocol == "vless" || profile.Protocol == "trojan") {
		settings.Security = "none"
	}

	switch profile.Network {
	case "ws":
		settings.WSSettings = &generatedWSSettings{
			Path:    profile.Path,
			Headers: map[string]string{"Host": profile.Host},
		}
	case "grpc":
		settings.GRPCSettings = &generatedGRPCSettings{ServiceName: profile.ServiceName}
	case "xhttp":
		settings.XHTTPSettings = &generatedXHTTPSettings{
			Host: profile.Host,
			Path: profile.Path,
			Mode: profile.xhttpMode(),
		}
	case "tcp":
		if profile.Security == "reality" {
			settings.RealitySettings = &generatedRealitySettings{
				Show:        false,
				Dest:        fmt.Sprintf("%s:443", profile.ServerName),
				Xver:        0,
				ServerNames: []string{profile.ServerName},
				PrivateKey:  profile.PrivateKey,
				PublicKey:   profile.PublicKey,
				ShortIDs:    []string{""},
			}
		}
		if profile.HeaderType != "" {
			settings.TCPSettings = &generatedTCPSettings{
				Header: generatedTCPHeader{Type: profile.HeaderType},
			}
		}
	}

	return settings
}
