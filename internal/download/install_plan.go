package download

func InstallSteps(kind string) []string {
	switch kind {
	case "core":
		return []string{
			"create /etc/xray/bin",
			"extract core archive to /etc/xray/bin",
			"chmod +x /etc/xray/bin/xray",
			"restart xray after config test",
		}
	case "script":
		return []string{
			"script runtime removed; use Go CLI asset",
			"install xray binary to /usr/local/bin/xray",
			"run xray install for system setup",
		}
	case "caddy":
		return []string{
			"extract caddy tarball",
			"install caddy to /usr/local/bin/caddy",
			"chmod +x /usr/local/bin/caddy",
			"reload caddy when configured",
		}
	case "dat":
		return []string{
			"copy geoip.dat to /etc/xray/bin",
			"copy geosite.dat to /etc/xray/bin",
			"restart xray after config test",
		}
	case "jq":
		return []string{
			"install jq to /usr/bin/jq",
			"chmod +x /usr/bin/jq",
		}
	case "go":
		return []string{
			"extract Go CLI tarball",
			"install xray binary to /usr/local/bin/xray",
			"run xray install for system setup",
		}
	default:
		return nil
	}
}
