package protocol

import (
	"fmt"
	"strings"
)

func MihomoProxyYAML(profile Profile) (string, bool, string, error) {
	if err := profile.Validate(); err != nil {
		return "", false, "", err
	}

	if profile.Protocol == "trojan" && profile.Network == "xhttp" {
		reason := fmt.Sprintf("# skip %q: mihomo trojan transport supports ws/grpc/tcp only", profile.Name)
		return reason, false, reason, nil
	}

	var b strings.Builder
	node := profile.Node()
	fmt.Fprintf(&b, "  - name: %q\n", profile.Name)

	switch profile.Protocol {
	case "vless":
		fmt.Fprintln(&b, "    type: vless")
		fmt.Fprintf(&b, "    server: %q\n", node.Address())
		fmt.Fprintf(&b, "    port: %d\n", node.PublicPort())
		fmt.Fprintf(&b, "    uuid: %q\n", profile.ID)
		fmt.Fprintln(&b, "    udp: true")
		if profile.Security == "reality" {
			fmt.Fprintln(&b, "    tls: true")
			fmt.Fprintf(&b, "    flow: %s\n", valueOr(profile.Flow, "xtls-rprx-vision"))
			fmt.Fprintf(&b, "    servername: %q\n", profile.ServerName)
			fmt.Fprintf(&b, "    client-fingerprint: %s\n", valueOr(profile.Fingerprint, "ios"))
			fmt.Fprintln(&b, "    reality-opts:")
			fmt.Fprintf(&b, "      public-key: %q\n", profile.PublicKey)
			fmt.Fprintln(&b, "      short-id: \"\"")
			return b.String(), true, "", nil
		}
		if profile.Security == "tls" {
			fmt.Fprintln(&b, "    tls: true")
			fmt.Fprintf(&b, "    servername: %q\n", profile.Host)
		}
		writeMihomoNetwork(&b, profile)
	case "vmess":
		fmt.Fprintln(&b, "    type: vmess")
		fmt.Fprintf(&b, "    server: %q\n", node.Address())
		fmt.Fprintf(&b, "    port: %d\n", node.PublicPort())
		fmt.Fprintf(&b, "    uuid: %q\n", profile.ID)
		fmt.Fprintln(&b, "    alterId: 0")
		fmt.Fprintf(&b, "    cipher: %q\n", "auto")
		fmt.Fprintln(&b, "    udp: true")
		if profile.HeaderType != "" {
			fmt.Fprintf(&b, "    network: %s\n", profile.Network)
		}
	case "shadowsocks":
		fmt.Fprintln(&b, "    type: ss")
		fmt.Fprintf(&b, "    server: %q\n", node.Address())
		fmt.Fprintf(&b, "    port: %d\n", node.PublicPort())
		fmt.Fprintf(&b, "    cipher: %q\n", profile.Method)
		fmt.Fprintf(&b, "    password: %q\n", profile.Password)
		fmt.Fprintln(&b, "    udp: true")
	case "socks":
		fmt.Fprintln(&b, "    type: socks5")
		fmt.Fprintf(&b, "    server: %q\n", node.Address())
		fmt.Fprintf(&b, "    port: %d\n", node.PublicPort())
		fmt.Fprintf(&b, "    username: %q\n", profile.ID)
		fmt.Fprintf(&b, "    password: %q\n", profile.Password)
		fmt.Fprintln(&b, "    udp: true")
	default:
		return "", false, "", fmt.Errorf("unsupported mihomo protocol: %s", profile.Protocol)
	}

	return b.String(), true, "", nil
}

func MihomoDocument(profiles []Profile) (string, error) {
	var b strings.Builder
	var proxyNames []string

	fmt.Fprintln(&b, "mixed-port: 7890")
	fmt.Fprintln(&b, "allow-lan: false")
	fmt.Fprintln(&b, "mode: rule")
	fmt.Fprintln(&b, "log-level: info")
	fmt.Fprintln(&b, "proxies:")

	for _, profile := range profiles {
		yaml, supported, _, err := MihomoProxyYAML(profile)
		if err != nil {
			return "", err
		}
		if supported {
			b.WriteString(yaml)
			proxyNames = append(proxyNames, profile.Name)
			continue
		}
		fmt.Fprintf(&b, "  %s\n", yaml)
	}

	fmt.Fprintln(&b, "proxy-groups:")
	fmt.Fprintln(&b, "  - name: PROXY")
	fmt.Fprintln(&b, "    type: select")
	fmt.Fprintln(&b, "    proxies:")
	for _, name := range proxyNames {
		fmt.Fprintf(&b, "      - %q\n", name)
	}
	fmt.Fprintln(&b, "      - DIRECT")
	fmt.Fprintln(&b, "rules:")
	fmt.Fprintln(&b, "  - GEOIP,CN,DIRECT")
	fmt.Fprintln(&b, "  - MATCH,PROXY")

	return b.String(), nil
}

func writeMihomoNetwork(b *strings.Builder, profile Profile) {
	switch profile.Network {
	case "ws":
		fmt.Fprintln(b, "    network: ws")
		fmt.Fprintln(b, "    ws-opts:")
		fmt.Fprintf(b, "      path: %q\n", profile.Path)
		fmt.Fprintln(b, "      headers:")
		fmt.Fprintf(b, "        Host: %q\n", profile.Host)
	case "grpc":
		fmt.Fprintln(b, "    network: grpc")
		fmt.Fprintln(b, "    grpc-opts:")
		fmt.Fprintf(b, "      grpc-service-name: %q\n", profile.ServiceName)
	case "xhttp":
		fmt.Fprintln(b, "    network: xhttp")
		fmt.Fprintln(b, "    alpn:")
		fmt.Fprintln(b, "      - h2")
		fmt.Fprintln(b, "    xhttp-opts:")
		fmt.Fprintf(b, "      path: %q\n", profile.Path)
		fmt.Fprintf(b, "      host: %q\n", profile.Host)
		fmt.Fprintf(b, "      mode: %q\n", profile.xhttpMode())
	}
}
