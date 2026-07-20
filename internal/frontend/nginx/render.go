package nginx

import (
	"bytes"
	"fmt"
	"strings"
	"text/template"

	"github.com/WangYan-Good/xray/internal/protocol"
)

const (
	SiteDir     = "/etc/nginx/xray"
	CertbotRoot = "/var/www/certbot"
	LiveDir     = "/etc/letsencrypt/live"
)

type Route struct {
	Kind        string
	Domain      string
	Path        string
	Port        int
	Comment     string
	ProxyScheme string
}

type siteData struct {
	Domain      string
	CertbotRoot string
	CertPath    string
	KeyPath     string
	IncludePath string
	Route       string
}

var siteTemplate = template.Must(template.New("nginx-site").Parse(`# {{ .Domain }} - Xray TLS frontend

server {
    listen 80;
    listen [::]:80;
    server_name {{ .Domain }};

    location ^~ /.well-known/acme-challenge/ {
        root {{ .CertbotRoot }};
        try_files $uri =404;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name {{ .Domain }};

    ssl_certificate {{ .CertPath }};
    ssl_certificate_key {{ .KeyPath }};

{{ .Route }}

    include {{ .IncludePath }};
}
`))

var bootstrapTemplate = template.Must(template.New("nginx-bootstrap").Parse(`# {{ .Domain }} - Xray ACME bootstrap

server {
    listen 80;
    listen [::]:80;
    server_name {{ .Domain }};

    location ^~ /.well-known/acme-challenge/ {
        root {{ .CertbotRoot }};
        try_files $uri =404;
    }

    location / {
        default_type text/plain;
        return 503 "TLS certificate provisioning in progress\n";
    }
}
`))

var proxyLocationTemplate = template.Must(template.New("nginx-proxy-location").Parse(`    # {{ .Comment }}
    location {{ .Path }} {
        proxy_pass http://127.0.0.1:{{ .Port }};
        proxy_http_version 1.1;{{ if eq .Kind "ws" }}
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";{{ end }}
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
        proxy_buffering off;
    }`))

var grpcLocationTemplate = template.Must(template.New("nginx-grpc-location").Parse(`    # {{ .Comment }}
    location {{ .Path }} {
        grpc_pass grpc://127.0.0.1:{{ .Port }};
        grpc_set_header Host $host;
        grpc_set_header X-Real-IP $remote_addr;
        grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        grpc_read_timeout 300s;
    }`))

func RenderSite(profile protocol.Profile) (string, error) {
	route, err := routeForProfile(profile)
	if err != nil {
		return "", err
	}
	location, err := RenderAdd(profile)
	if err != nil {
		return "", err
	}

	data := siteData{
		Domain:      route.Domain,
		CertbotRoot: CertbotRoot,
		CertPath:    fmt.Sprintf("%s/%s/fullchain.pem", LiveDir, route.Domain),
		KeyPath:     fmt.Sprintf("%s/%s/privkey.pem", LiveDir, route.Domain),
		IncludePath: fmt.Sprintf("%s/%s.conf.add", SiteDir, route.Domain),
		Route:       strings.TrimRight(location, "\n"),
	}
	return execute(siteTemplate, data)
}

func RenderBootstrap(domain string) (string, error) {
	if err := ValidateDomain(domain); err != nil {
		return "", err
	}
	return execute(bootstrapTemplate, siteData{Domain: domain, CertbotRoot: CertbotRoot})
}

func RenderAdd(profile protocol.Profile) (string, error) {
	route, err := routeForProfile(profile)
	if err != nil {
		return "", err
	}
	if route.Kind == "grpc" {
		return execute(grpcLocationTemplate, route)
	}
	return execute(proxyLocationTemplate, route)
}

func routeForProfile(profile protocol.Profile) (Route, error) {
	if err := profile.Validate(); err != nil {
		return Route{}, err
	}
	if profile.Host == "" {
		return Route{}, fmt.Errorf("%s: no TLS frontend host", profile.Key)
	}
	if err := ValidateDomain(profile.Host); err != nil {
		return Route{}, fmt.Errorf("%s: %w", profile.Key, err)
	}
	if err := ValidateBackendPort(profile.Port); err != nil {
		return Route{}, fmt.Errorf("%s: %w", profile.Key, err)
	}

	route := Route{
		Kind:   profile.Network,
		Domain: profile.Host,
		Port:   profile.Port,
	}
	switch profile.Network {
	case "ws":
		route.Path = ensureLeadingSlash(profile.Path)
		route.Comment = fmt.Sprintf("Xray WebSocket: %s%s", profile.Host, route.Path)
	case "xhttp":
		route.Path = ensureLeadingSlash(profile.Path)
		route.Comment = fmt.Sprintf("Xray HTTP/2: %s%s", profile.Host, route.Path)
	case "grpc":
		route.Path = ensureTrailingSlash(ensureLeadingSlash(profile.ServiceName))
		route.Comment = fmt.Sprintf("Xray gRPC: %s%s", profile.Host, route.Path)
	default:
		return Route{}, fmt.Errorf("%s: protocol has no Nginx frontend template", profile.Key)
	}
	return route, nil
}

func execute(tmpl *template.Template, data any) (string, error) {
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, data); err != nil {
		return "", err
	}
	return strings.TrimRight(buf.String(), "\n") + "\n", nil
}

func ensureLeadingSlash(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return "/"
	}
	if strings.HasPrefix(value, "/") {
		return value
	}
	return "/" + value
}

func ensureTrailingSlash(value string) string {
	if strings.HasSuffix(value, "/") {
		return value
	}
	return value + "/"
}
