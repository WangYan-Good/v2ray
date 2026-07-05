package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type inboundFile struct {
	Inbounds []rawInbound `json:"inbounds"`
}

type rawInbound struct {
	Tag            string            `json:"tag"`
	Port           int               `json:"port"`
	Listen         string            `json:"listen"`
	Protocol       string            `json:"protocol"`
	Settings       rawSettings       `json:"settings"`
	StreamSettings rawStreamSettings `json:"streamSettings"`
}

type rawSettings struct {
	Clients    []rawClient  `json:"clients"`
	Method     string       `json:"method"`
	Password   string       `json:"password"`
	Network    string       `json:"network"`
	Auth       string       `json:"auth"`
	Accounts   []rawAccount `json:"accounts"`
	Decryption string       `json:"decryption"`
}

type rawClient struct {
	ID       string `json:"id"`
	Password string `json:"password"`
	Flow     string `json:"flow"`
}

type rawAccount struct {
	User string `json:"user"`
	Pass string `json:"pass"`
}

type rawStreamSettings struct {
	Network         string             `json:"network"`
	Security        string             `json:"security"`
	WSSettings      rawWSSettings      `json:"wsSettings"`
	GRPCSettings    rawGRPCSettings    `json:"grpcSettings"`
	XHTTPSettings   rawXHTTPSettings   `json:"xhttpSettings"`
	RealitySettings rawRealitySettings `json:"realitySettings"`
	TCPSettings     rawTCPSettings     `json:"tcpSettings"`
}

type rawWSSettings struct {
	Path    string            `json:"path"`
	Headers map[string]string `json:"headers"`
}

type rawGRPCSettings struct {
	ServiceName string `json:"serviceName"`
}

type rawXHTTPSettings struct {
	Host string `json:"host"`
	Path string `json:"path"`
	Mode string `json:"mode"`
}

type rawRealitySettings struct {
	ServerNames []string `json:"serverNames"`
	PublicKey   string   `json:"publicKey"`
}

type rawTCPSettings struct {
	Header rawTCPHeader `json:"header"`
}

type rawTCPHeader struct {
	Type string `json:"type"`
}

func ListNodes(confDir string) ([]Node, error) {
	entries, err := os.ReadDir(confDir)
	if err != nil {
		return nil, err
	}

	var nodes []Node
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if !strings.HasSuffix(strings.ToLower(name), ".json") || strings.HasSuffix(strings.ToLower(name), "-link.json") {
			continue
		}
		node, err := ReadNode(filepath.Join(confDir, name))
		if err != nil {
			return nil, err
		}
		nodes = append(nodes, node)
	}

	sort.Slice(nodes, func(i, j int) bool {
		return strings.ToLower(nodes[i].FileName) < strings.ToLower(nodes[j].FileName)
	})
	return nodes, nil
}

func ReadNode(path string) (Node, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Node{}, err
	}

	var file inboundFile
	if err := json.Unmarshal(data, &file); err != nil {
		return Node{}, err
	}
	if len(file.Inbounds) == 0 {
		return Node{}, fmt.Errorf("%s: no inbounds", filepath.Base(path))
	}

	in := file.Inbounds[0]
	node := Node{
		Name:        InferName(path),
		FileName:    filepath.Base(path),
		Protocol:    in.Protocol,
		Port:        in.Port,
		Listen:      in.Listen,
		Method:      in.Settings.Method,
		Network:     in.StreamSettings.Network,
		Security:    in.StreamSettings.Security,
		Path:        in.StreamSettings.WSSettings.Path,
		ServiceName: in.StreamSettings.GRPCSettings.ServiceName,
		PublicKey:   in.StreamSettings.RealitySettings.PublicKey,
		HeaderType:  in.StreamSettings.TCPSettings.Header.Type,
		Fingerprint: "ios",
	}

	if len(in.Settings.Clients) > 0 {
		node.ID = in.Settings.Clients[0].ID
		node.Password = in.Settings.Clients[0].Password
		node.Flow = in.Settings.Clients[0].Flow
	}
	if node.Password == "" {
		node.Password = in.Settings.Password
	}
	if len(in.Settings.Accounts) > 0 {
		node.ID = in.Settings.Accounts[0].User
		node.Password = in.Settings.Accounts[0].Pass
	}
	if node.Network == "" && in.Protocol == "shadowsocks" {
		node.Network = in.Settings.Network
	}

	if host := in.StreamSettings.WSSettings.Headers["Host"]; host != "" {
		node.Host = host
	}
	if in.StreamSettings.XHTTPSettings.Host != "" {
		node.Host = in.StreamSettings.XHTTPSettings.Host
	}
	if in.StreamSettings.XHTTPSettings.Path != "" {
		node.Path = in.StreamSettings.XHTTPSettings.Path
	}
	if len(in.StreamSettings.RealitySettings.ServerNames) > 0 {
		node.ServerName = in.StreamSettings.RealitySettings.ServerNames[0]
	}
	if node.Host == "" {
		node.Host = inferHostFromName(node.Name)
	}
	if node.Host == "" {
		node.Host = inferHostFromName(in.Tag)
	}

	if err := node.Validate(); err != nil {
		return Node{}, err
	}
	return node, nil
}

func MatchNode(confDir, query string) (Node, error) {
	nodes, err := ListNodes(confDir)
	if err != nil {
		return Node{}, err
	}
	if len(nodes) == 0 {
		return Node{}, fmt.Errorf("no config files found in %s", confDir)
	}
	if query == "" {
		if len(nodes) == 1 {
			return nodes[0], nil
		}
		return Node{}, fmt.Errorf("config name required; candidates: %s", candidateList(nodes))
	}

	queryLower := strings.ToLower(query)
	for _, node := range nodes {
		if strings.ToLower(node.FileName) == queryLower || strings.ToLower(node.Name) == queryLower {
			return node, nil
		}
	}

	var matches []Node
	for _, node := range nodes {
		if strings.Contains(strings.ToLower(node.FileName), queryLower) || strings.Contains(strings.ToLower(node.Name), queryLower) {
			matches = append(matches, node)
		}
	}
	switch len(matches) {
	case 1:
		return matches[0], nil
	case 0:
		return Node{}, fmt.Errorf("config not found: %s", query)
	default:
		return Node{}, fmt.Errorf("multiple configs match %q: %s", query, candidateList(matches))
	}
}

func candidateList(nodes []Node) string {
	names := make([]string, 0, len(nodes))
	for _, node := range nodes {
		names = append(names, node.FileName)
	}
	sort.Strings(names)
	return strings.Join(names, ", ")
}
