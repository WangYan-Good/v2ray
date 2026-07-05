package caddy

import (
	"bytes"
	"fmt"
	"strings"
	"text/template"

	"github.com/WangYan-Good/xray/internal/protocol"
)

const (
	SiteDir          = "/etc/caddy/WangYan-Good"
	DefaultCaddyfile = "/etc/caddy/Caddyfile"
)

type Route struct {
	Kind    string
	Domain  string
	Path    string
	Port    int
	Comment string
	Target  string
}

type siteData struct {
	Domain     string
	ImportPath string
	Route      string
}

var siteTemplate = template.Must(template.New("caddy-site").Parse(`{{ .Domain }} {
    encode gzip

{{ .Route }}

    import {{ .ImportPath }}
}
`))

var routeTemplate = template.Must(template.New("caddy-route").Parse(`    # {{ .Comment }}
    reverse_proxy {{ .Path }} {{ .Target }}`))

var addRouteTemplate = template.Must(template.New("caddy-add-route").Parse(`# {{ .Comment }}
reverse_proxy {{ .Path }} {{ .Target }}
`))

func RenderSite(profile protocol.Profile) (string, error) {
	route, err := routeForProfile(profile)
	if err != nil {
		return "", err
	}
	routeText, err := execute(routeTemplate, route)
	if err != nil {
		return "", err
	}
	data := siteData{
		Domain:     route.Domain,
		ImportPath: fmt.Sprintf("%s/%s.conf.add", SiteDir, route.Domain),
		Route:      strings.TrimRight(routeText, "\n"),
	}
	return execute(siteTemplate, data)
}

func RenderAdd(profile protocol.Profile) (string, error) {
	route, err := routeForProfile(profile)
	if err != nil {
		return "", err
	}
	return execute(addRouteTemplate, route)
}

func routeForProfile(profile protocol.Profile) (Route, error) {
	if err := profile.Validate(); err != nil {
		return Route{}, err
	}
	if profile.Host == "" {
		return Route{}, fmt.Errorf("%s: no TLS frontend host", profile.Key)
	}

	route := Route{
		Kind:   profile.Network,
		Domain: profile.Host,
		Port:   profile.Port,
	}
	switch profile.Network {
	case "ws":
		route.Path = ensureLeadingSlash(profile.Path)
		route.Comment = "Xray ws"
		route.Target = fmt.Sprintf("127.0.0.1:%d", profile.Port)
	case "xhttp":
		route.Path = ensureLeadingSlash(profile.Path)
		route.Comment = "Xray xhttp"
		route.Target = fmt.Sprintf("127.0.0.1:%d", profile.Port)
	case "grpc":
		route.Path = ensureLeadingSlash(profile.ServiceName) + "/*"
		route.Comment = "Xray grpc"
		route.Target = fmt.Sprintf("h2c://127.0.0.1:%d", profile.Port)
	default:
		return Route{}, fmt.Errorf("%s: protocol has no Caddy frontend template", profile.Key)
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
