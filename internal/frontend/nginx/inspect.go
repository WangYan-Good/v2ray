package nginx

import (
	"fmt"
	"net"
	"path/filepath"
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
	domainLabelRE   = regexp.MustCompile(`^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$`)
)

func ValidateDomain(domain string) error {
	domain = strings.ToLower(strings.TrimSpace(domain))
	if domain == "" || len(domain) > 253 {
		return fmt.Errorf("invalid domain name")
	}
	if net.ParseIP(strings.Trim(domain, "[]")) != nil {
		return fmt.Errorf("domain must not be an IP address")
	}
	domain = strings.TrimSuffix(domain, ".")
	labels := strings.Split(domain, ".")
	if len(labels) < 2 {
		return fmt.Errorf("domain must contain at least two labels")
	}
	for _, label := range labels {
		if !domainLabelRE.MatchString(label) {
			return fmt.Errorf("invalid domain name")
		}
	}
	return nil
}

func ValidateBackendPort(port int) error {
	if port < 1 || port > 65535 {
		return fmt.Errorf("invalid Xray backend port: %d", port)
	}
	return nil
}

func RemoveManagedCertbotRedirects(content, domain string) (string, bool) {
	pattern := `(?ms)^[ \t]*if[ \t]+\(\$host[ \t]*=[ \t]*` + regexp.QuoteMeta(domain) + `\)[ \t]*\{\s*` +
		`return[ \t]+301[ \t]+https://\$host\$request_uri;\s*\}[ \t]*#[ \t]*managed by Certbot[ \t]*\n?`
	re := regexp.MustCompile(pattern)
	out := re.ReplaceAllString(content, "")
	return out, out != content
}

func CheckAppend(mainConf, addConf string, profile protocol.Profile) (AppendCheck, error) {
	route, err := routeForProfile(profile)
	if err != nil {
		return AppendCheck{}, err
	}
	if err := ValidateBackendPort(route.Port); err != nil {
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

func EnsureHTTPInclude(content, includePath string) (string, bool, error) {
	nginxDir := filepath.Dir(filepath.Dir(includePath))
	directSiteInclude := "include " + filepath.Join(nginxDir, "xray", "*.conf") + ";"
	if strings.Contains(content, "include /etc/nginx/conf.d/*.conf;") || strings.Contains(content, "include "+includePath+";") || strings.Contains(content, directSiteInclude) {
		return content, false, nil
	}
	lines := strings.Split(content, "\n")
	httpStart := -1
	depth := 0
	for index, line := range lines {
		trimmed := strings.TrimSpace(line)
		if httpStart < 0 {
			if strings.HasPrefix(trimmed, "http") && strings.Contains(trimmed, "{") {
				httpStart = index
				depth = braceDelta(line)
			}
			continue
		}
		depth += braceDelta(line)
		if depth == 0 {
			indent := strings.TrimSuffix(line, strings.TrimLeft(line, " \t"))
			include := indent + "    include " + includePath + ";"
			lines = append(lines[:index], append([]string{include}, lines[index:]...)...)
			return strings.Join(lines, "\n"), true, nil
		}
	}
	return "", false, fmt.Errorf("Nginx configuration has no unambiguous http block")
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
