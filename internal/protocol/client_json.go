package protocol

import "encoding/json"

type generatedClientConfig struct {
	Outbounds []generatedOutbound `json:"outbounds"`
}

type generatedOutbound struct {
	Tag            string                `json:"tag"`
	Protocol       string                `json:"protocol"`
	Settings       map[string]any        `json:"settings"`
	StreamSettings *clientStreamSettings `json:"streamSettings,omitempty"`
}

type clientStreamSettings struct {
	Network         string                  `json:"network,omitempty"`
	Security        string                  `json:"security,omitempty"`
	WSSettings      *generatedWSSettings    `json:"wsSettings,omitempty"`
	GRPCSettings    *generatedGRPCSettings  `json:"grpcSettings,omitempty"`
	XHTTPSettings   *generatedXHTTPSettings `json:"xhttpSettings,omitempty"`
	RealitySettings map[string]any          `json:"realitySettings,omitempty"`
	TCPSettings     *generatedTCPSettings   `json:"tcpSettings,omitempty"`
}

func ClientJSON(profile Profile) ([]byte, error) {
	if err := profile.Validate(); err != nil {
		return nil, err
	}
	node := profile.Node()
	outbound := generatedOutbound{
		Tag:            profile.Name,
		Protocol:       profile.Protocol,
		Settings:       clientSettings(profile, node.Address(), node.PublicPort()),
		StreamSettings: clientStream(profile),
	}
	out := generatedClientConfig{Outbounds: []generatedOutbound{outbound}}
	return json.MarshalIndent(out, "", "  ")
}

func clientSettings(profile Profile, address string, port int) map[string]any {
	switch profile.Protocol {
	case "vless":
		user := map[string]any{
			"id":         profile.ID,
			"encryption": "none",
		}
		if profile.Flow != "" {
			user["flow"] = profile.Flow
		}
		return map[string]any{
			"vnext": []map[string]any{{
				"address": address,
				"port":    port,
				"users":   []map[string]any{user},
			}},
		}
	case "vmess":
		return map[string]any{
			"vnext": []map[string]any{{
				"address": address,
				"port":    port,
				"users": []map[string]any{{
					"id":      profile.ID,
					"alterId": 0,
				}},
			}},
		}
	case "trojan":
		return map[string]any{
			"servers": []map[string]any{{
				"address":  address,
				"port":     port,
				"password": profile.Password,
			}},
		}
	case "shadowsocks":
		return map[string]any{
			"servers": []map[string]any{{
				"address":  address,
				"port":     port,
				"method":   profile.Method,
				"password": profile.Password,
			}},
		}
	case "socks":
		return map[string]any{
			"servers": []map[string]any{{
				"address": address,
				"port":    port,
				"users": []map[string]any{{
					"user": profile.ID,
					"pass": profile.Password,
				}},
			}},
		}
	default:
		return map[string]any{}
	}
}

func clientStream(profile Profile) *clientStreamSettings {
	if profile.Protocol == "shadowsocks" || profile.Protocol == "socks" {
		return nil
	}

	settings := &clientStreamSettings{
		Network:  profile.Network,
		Security: profile.Security,
	}
	if settings.Security == "" && profile.Host != "" {
		settings.Security = "tls"
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
			settings.RealitySettings = map[string]any{
				"serverName":  profile.ServerName,
				"fingerprint": valueOr(profile.Fingerprint, "ios"),
				"publicKey":   profile.PublicKey,
				"shortId":     "",
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
