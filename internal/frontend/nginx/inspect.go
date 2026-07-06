package nginx

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"

	"github.com/WangYan-Good/xray/internal/protocol"
)

type AppendStatus string

const (
	AppendAllowed  AppendStatus = "append"
	AppendSame     AppendStatus = "idempotent"
	AppendConflict AppendStatus = "conflict"
)

type AppendCheck struct {
	Status       AppendStatus
	Path         string
	WantedPort   int
	ExistingPort int
	Source       string
}

type Location struct {
	Path   string
	Port   int
	Source string
}

var (
	nginxLocationRe = regexp.MustCompile(`^\s*location\s+(?:=\s+)?([^\s{]+)`)
	nginxPassRe     = regexp.MustCompile(`(?:proxy_pass|grpc_pass)\s+(?:https?|grpc)://[^:;]+:(\d+)`)
)

func CheckAppend(mainConf, addConf string, profile protocol.Profile) (AppendCheck, error) {
	route, err := routeForProfile(profile)
	if err != nil {
		return AppendCheck{}, err
	}
	wantPath := normalizePath(route.Path)

	locations := append(ParseLocations(mainConf, "main"), ParseLocations(addConf, "add")...)
	for _, location := range locations {
		if normalizePath(location.Path) != wantPath {
			continue
		}
		check := AppendCheck{
			Path:         wantPath,
			WantedPort:   route.Port,
			ExistingPort: location.Port,
			Source:       location.Source,
		}
		if location.Port == route.Port {
			check.Status = AppendSame
			return check, nil
		}
		check.Status = AppendConflict
		return check, nil
	}

	return AppendCheck{
		Status:     AppendAllowed,
		Path:       wantPath,
		WantedPort: route.Port,
	}, nil
}

func ParseLocations(content, source string) []Location {
	lines := strings.Split(content, "\n")
	var locations []Location
	var currentPath string
	var currentPort int
	depth := 0

	for _, line := range lines {
		if currentPath == "" {
			matches := nginxLocationRe.FindStringSubmatch(line)
			if len(matches) == 2 {
				path := normalizePath(matches[1])
				if path == "/sub/mihomo" {
					continue
				}
				currentPath = path
				currentPort = 0
				depth = braceDelta(line)
				if depth == 0 {
					depth = 1
				}
				if port := passPort(line); port != 0 {
					currentPort = port
				}
				continue
			}
		} else {
			if port := passPort(line); port != 0 {
				currentPort = port
			}
			depth += braceDelta(line)
			if depth <= 0 {
				if currentPort != 0 {
					locations = append(locations, Location{Path: currentPath, Port: currentPort, Source: source})
				}
				currentPath = ""
				currentPort = 0
				depth = 0
			}
		}
	}
	return locations
}

func EnsureAddInclude(content, includePath string) (string, bool, error) {
	line := fmt.Sprintf("include %s;", includePath)
	if strings.Contains(content, line) {
		return content, false, nil
	}

	index := strings.LastIndex(content, "\n}")
	if index < 0 {
		return "", false, fmt.Errorf("no server block close found")
	}
	insert := fmt.Sprintf("\n    %s", line)
	return content[:index] + insert + content[index:], true, nil
}

func normalizePath(path string) string {
	path = strings.TrimSpace(path)
	path = strings.TrimSuffix(path, "{")
	path = strings.TrimSpace(path)
	path = strings.TrimSuffix(path, ";")
	if path == "" {
		return "/"
	}
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}
	for len(path) > 1 && strings.HasSuffix(path, "/") {
		path = strings.TrimSuffix(path, "/")
	}
	return path
}

func passPort(line string) int {
	matches := nginxPassRe.FindStringSubmatch(line)
	if len(matches) != 2 {
		return 0
	}
	port, _ := strconv.Atoi(matches[1])
	return port
}

func braceDelta(line string) int {
	return strings.Count(line, "{") - strings.Count(line, "}")
}
