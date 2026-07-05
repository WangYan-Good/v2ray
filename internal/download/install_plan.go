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
			"create /etc/xray/sh",
			"extract code.zip to /etc/xray/sh",
			"keep /usr/local/bin/xray on Bash entry until Phase 5",
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
			"install xray binary to /usr/local/bin/xray after Phase 5 switch",
			"run xray install through compatibility layer",
		}
	default:
		return nil
	}
}
