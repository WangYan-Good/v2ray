package download

import (
	"fmt"
	"sort"
	"strings"
)

const (
	CoreRepo   = "XTLS/Xray-core"
	ScriptRepo = "WangYan-Good/xray"
	CaddyRepo  = "caddyserver/caddy"
	DatRepo    = "Loyalsoldier/v2ray-rules-dat"
	JQRepo     = "jqlang/jq"
)

type Asset struct {
	Name          string
	URL           string
	ChecksumURL   string
	InstallTarget string
}

type Plan struct {
	Kind         string
	Version      string
	Machine      string
	Arch         Arch
	Assets       []Asset
	ProxyEnv     map[string]string
	InstallSteps []string
}

type PlanOptions struct {
	Kind    string
	Version string
	Machine string
	Proxy   string
}

func NewPlan(opts PlanOptions) (Plan, error) {
	kind := strings.ToLower(strings.TrimSpace(opts.Kind))
	if kind == "" {
		return Plan{}, fmt.Errorf("download kind required")
	}
	machine := valueOr(opts.Machine, "x86_64")
	arch, err := NormalizeArch(machine)
	if err != nil {
		return Plan{}, err
	}

	plan := Plan{
		Kind:     kind,
		Version:  strings.TrimSpace(opts.Version),
		Machine:  machine,
		Arch:     arch,
		ProxyEnv: ProxyEnvironment(opts.Proxy),
	}

	switch kind {
	case "core":
		asset := fmt.Sprintf("Xray-linux-%s.zip", arch.Xray)
		plan.Assets = []Asset{{
			Name:          asset,
			URL:           releaseURL(CoreRepo, plan.Version, asset),
			ChecksumURL:   releaseURL(CoreRepo, plan.Version, asset) + ".dgst",
			InstallTarget: "/etc/xray/bin",
		}}
		plan.InstallSteps = InstallSteps("core")
	case "script", "sh":
		plan.Kind = "go"
		asset := fmt.Sprintf("xray-linux-%s.tar.gz", arch.Go)
		plan.Assets = []Asset{{
			Name:          asset,
			URL:           releaseURL(ScriptRepo, plan.Version, asset),
			ChecksumURL:   releaseURL(ScriptRepo, plan.Version, "checksums.txt"),
			InstallTarget: "/usr/local/bin/xray",
		}}
		plan.InstallSteps = InstallSteps("go")
	case "caddy":
		if plan.Version == "" || plan.Version == "latest" {
			return Plan{}, fmt.Errorf("caddy version required to build asset name")
		}
		asset := fmt.Sprintf("caddy_%s_linux_%s.tar.gz", strings.TrimPrefix(plan.Version, "v"), arch.Caddy)
		plan.Assets = []Asset{{
			Name:          asset,
			URL:           releaseURL(CaddyRepo, plan.Version, asset),
			ChecksumURL:   releaseURL(CaddyRepo, plan.Version, fmt.Sprintf("caddy_%s_checksums.txt", strings.TrimPrefix(plan.Version, "v"))),
			InstallTarget: "/usr/local/bin/caddy",
		}}
		plan.InstallSteps = InstallSteps("caddy")
	case "dat":
		plan.Assets = []Asset{
			{
				Name:          "geoip.dat",
				URL:           latestDownloadURL(DatRepo, "geoip.dat"),
				InstallTarget: "/etc/xray/bin",
			},
			{
				Name:          "geosite.dat",
				URL:           latestDownloadURL(DatRepo, "geosite.dat"),
				InstallTarget: "/etc/xray/bin",
			},
		}
		plan.InstallSteps = InstallSteps("dat")
	case "jq":
		version := valueOr(plan.Version, "jq-1.7.1")
		asset := fmt.Sprintf("jq-linux-%s", arch.JQ)
		plan.Assets = []Asset{{
			Name:          asset,
			URL:           releaseURL(JQRepo, version, asset),
			ChecksumURL:   releaseAPIURL(JQRepo, version),
			InstallTarget: "/usr/bin/jq",
		}}
		plan.Version = version
		plan.InstallSteps = InstallSteps("jq")
	case "go", "go-cli", "binary":
		plan.Kind = "go"
		asset := fmt.Sprintf("xray-linux-%s.tar.gz", arch.Go)
		plan.Assets = []Asset{{
			Name:          asset,
			URL:           releaseURL(ScriptRepo, plan.Version, asset),
			ChecksumURL:   releaseURL(ScriptRepo, plan.Version, "checksums.txt"),
			InstallTarget: "/usr/local/bin/xray",
		}}
		plan.InstallSteps = InstallSteps("go")
	default:
		return Plan{}, fmt.Errorf("unsupported download kind: %s", kind)
	}

	return plan, nil
}

func ProxyEnvironment(proxy string) map[string]string {
	proxy = strings.TrimSpace(proxy)
	if proxy == "" {
		return nil
	}
	return map[string]string{
		"http_proxy":  proxy,
		"https_proxy": proxy,
		"HTTP_PROXY":  proxy,
		"HTTPS_PROXY": proxy,
	}
}

func FormatPlan(plan Plan) string {
	var b strings.Builder
	fmt.Fprintf(&b, "kind = %s\n", plan.Kind)
	fmt.Fprintf(&b, "version = %s\n", valueOr(plan.Version, "latest"))
	fmt.Fprintf(&b, "machine = %s\n", plan.Machine)
	fmt.Fprintf(&b, "arch.go = %s\n", plan.Arch.Go)
	fmt.Fprintf(&b, "arch.xray = %s\n", plan.Arch.Xray)
	fmt.Fprintf(&b, "arch.caddy = %s\n", plan.Arch.Caddy)
	fmt.Fprintf(&b, "arch.jq = %s\n", plan.Arch.JQ)
	for i, asset := range plan.Assets {
		fmt.Fprintf(&b, "asset.%d.name = %s\n", i, asset.Name)
		fmt.Fprintf(&b, "asset.%d.url = %s\n", i, asset.URL)
		if asset.ChecksumURL != "" {
			fmt.Fprintf(&b, "asset.%d.checksum_url = %s\n", i, asset.ChecksumURL)
		}
		fmt.Fprintf(&b, "asset.%d.install_target = %s\n", i, asset.InstallTarget)
	}

	keys := make([]string, 0, len(plan.ProxyEnv))
	for key := range plan.ProxyEnv {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		fmt.Fprintf(&b, "proxy.%s = %s\n", key, plan.ProxyEnv[key])
	}

	for i, step := range plan.InstallSteps {
		fmt.Fprintf(&b, "install_step.%d = %s\n", i, step)
	}
	return b.String()
}

func releaseURL(repo, version, asset string) string {
	if version == "" || version == "latest" {
		return latestDownloadURL(repo, asset)
	}
	return fmt.Sprintf("https://github.com/%s/releases/download/%s/%s", repo, version, asset)
}

func latestDownloadURL(repo, asset string) string {
	return fmt.Sprintf("https://github.com/%s/releases/latest/download/%s", repo, asset)
}

func releaseAPIURL(repo, version string) string {
	if version == "" || version == "latest" {
		return fmt.Sprintf("https://api.github.com/repos/%s/releases/latest", repo)
	}
	return fmt.Sprintf("https://api.github.com/repos/%s/releases/tags/%s", repo, version)
}

func valueOr(value, fallback string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return fallback
	}
	return value
}
