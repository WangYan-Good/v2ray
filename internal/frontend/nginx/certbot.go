package nginx

import (
	"fmt"
	"path/filepath"
	"regexp"
	"strings"
)

const (
	DeployHookPath = "/etc/letsencrypt/renewal-hooks/deploy/xray-nginx-reload"
	DeployHook     = `#!/usr/bin/env bash
set -euo pipefail
nginx -t
systemctl reload nginx
`
)

var oldSSLDirectiveRE = regexp.MustCompile(`(?m)(ssl_certificate(?:_key)?\s+)/etc/nginx/ssl/([^/;\s]+)/((?:fullchain|privkey)\.pem)(;)`)

func CertificatePath(domain string) string {
	return filepath.Join(LiveDir, domain, "fullchain.pem")
}

func PrivateKeyPath(domain string) string {
	return filepath.Join(LiveDir, domain, "privkey.pem")
}

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

func RemoveNginxInstaller(content string) (string, bool) {
	lines := strings.Split(content, "\n")
	out := make([]string, 0, len(lines))
	changed := false
	for _, line := range lines {
		if strings.TrimSpace(line) == "installer = nginx" {
			changed = true
			continue
		}
		out = append(out, line)
	}
	return strings.TrimRight(strings.Join(out, "\n"), "\n") + "\n", changed
}

// MigrateCertificatePaths changes only directives for the expected managed domain.
// The caller must verify the Let's Encrypt certificate before setting verified=true.
func MigrateCertificatePaths(content, domain string, verified bool) (string, bool, string) {
	if !strings.Contains(content, "/etc/nginx/ssl/") {
		return content, false, ""
	}
	if !verified {
		return content, false, "valid Let's Encrypt certificate not confirmed; old certificate path retained"
	}
	changed := false
	out := oldSSLDirectiveRE.ReplaceAllStringFunc(content, func(match string) string {
		parts := oldSSLDirectiveRE.FindStringSubmatch(match)
		if len(parts) != 5 || parts[2] != domain {
			return match
		}
		changed = true
		return parts[1] + filepath.Join(LiveDir, domain, parts[3]) + parts[4]
	})
	return out, changed, ""
}
