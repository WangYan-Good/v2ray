package nginx

import (
	"fmt"
	"strings"
)

func RenewalAuthenticator(content string) string {
	for _, line := range strings.Split(content, "\n") {
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		if strings.TrimSpace(parts[0]) == "authenticator" {
			return strings.TrimSpace(parts[1])
		}
	}
	return ""
}

func RenewalUsesWebroot(content, domain string) bool {
	return RenewalAuthenticator(content) == "webroot" &&
		strings.Contains(content, "webroot_path = /var/www/certbot,") &&
		strings.Contains(content, fmt.Sprintf("%s = /var/www/certbot", domain))
}

func EnsureWebrootRenewal(content, domain string) (string, bool) {
	lines := strings.Split(content, "\n")
	changed := false
	sawAuth := false
	sawPath := false
	sawMap := false
	sawDomain := false

	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		switch {
		case strings.HasPrefix(trimmed, "authenticator"):
			sawAuth = true
			if trimmed != "authenticator = webroot" {
				lines[i] = "authenticator = webroot"
				changed = true
			}
		case strings.HasPrefix(trimmed, "webroot_path"):
			sawPath = true
			if trimmed != "webroot_path = /var/www/certbot," {
				lines[i] = "webroot_path = /var/www/certbot,"
				changed = true
			}
		case trimmed == "[[webroot_map]]":
			sawMap = true
		case trimmed == fmt.Sprintf("%s = /var/www/certbot", domain):
			sawDomain = true
		}
	}

	if !sawAuth {
		lines = append(lines, "authenticator = webroot")
		changed = true
	}
	if !sawPath {
		lines = append(lines, "webroot_path = /var/www/certbot,")
		changed = true
	}
	if !sawMap {
		lines = append(lines, "[[webroot_map]]")
		changed = true
	}
	if !sawDomain {
		lines = append(lines, fmt.Sprintf("%s = /var/www/certbot", domain))
		changed = true
	}

	out := strings.Join(lines, "\n")
	return strings.TrimRight(out, "\n") + "\n", changed
}
