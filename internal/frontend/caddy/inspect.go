package caddy

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

type ReverseProxy struct {
	Path   string
	Port   int
	Source string
}

var (
	caddyReverseProxyRe = regexp.MustCompile(`^\s*reverse_proxy\s+(\S+)\s+(\S+)`)
	caddyPortRe         = regexp.MustCompile(`:(\d+)$`)
)

func CheckAppend(mainConf, addConf string, profile protocol.Profile) (AppendCheck, error) {
	route, err := routeForProfile(profile)
	if err != nil {
		return AppendCheck{}, err
	}
	wantPath := normalizePath(route.Path)

	proxies := append(ParseReverseProxies(mainConf, "main"), ParseReverseProxies(addConf, "add")...)
	for _, proxy := range proxies {
		if normalizePath(proxy.Path) != wantPath {
			continue
		}
		check := AppendCheck{
			Path:         wantPath,
			WantedPort:   route.Port,
			ExistingPort: proxy.Port,
			Source:       proxy.Source,
		}
		if proxy.Port == route.Port {
			check.Status = AppendSame
			return check, nil
		}
		check.Status = AppendConflict
		return check, nil
	}

	return AppendCheck{Status: AppendAllowed, Path: wantPath, WantedPort: route.Port}, nil
}

func ParseReverseProxies(content, source string) []ReverseProxy {
	var proxies []ReverseProxy
	for _, line := range strings.Split(content, "\n") {
		matches := caddyReverseProxyRe.FindStringSubmatch(line)
		if len(matches) != 3 {
			continue
		}
		port := targetPort(matches[2])
		if port == 0 {
			continue
		}
		proxies = append(proxies, ReverseProxy{
			Path:   normalizePath(matches[1]),
			Port:   port,
			Source: source,
		})
	}
	return proxies
}

func EnsureAddImport(content, importPath string) (string, bool, error) {
	line := fmt.Sprintf("import %s", importPath)
	if strings.Contains(content, line) {
		return content, false, nil
	}

	index := strings.LastIndex(content, "\n}")
	if index < 0 {
		return "", false, fmt.Errorf("no site block close found")
	}
	insert := fmt.Sprintf("\n    %s", line)
	return content[:index] + insert + content[index:], true, nil
}

func normalizePath(path string) string {
	path = strings.TrimSpace(path)
	path = strings.TrimSuffix(path, "{")
	path = strings.TrimSuffix(path, "/*")
	path = strings.TrimSuffix(path, "/")
	path = strings.TrimPrefix(path, "/")
	if path == "" {
		return "/"
	}
	return "/" + path
}

func targetPort(target string) int {
	target = strings.TrimSpace(target)
	matches := caddyPortRe.FindStringSubmatch(target)
	if len(matches) != 2 {
		return 0
	}
	port, _ := strconv.Atoi(matches[1])
	return port
}
