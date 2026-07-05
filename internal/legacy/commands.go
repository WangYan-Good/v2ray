package legacy

import "strings"

const DefaultPath = "/etc/xray/sh/xray.sh"

var migratedCommands = map[string]struct{}{
	"version":       {},
	"ver":           {},
	"v":             {},
	"status":        {},
	"s":             {},
	"info":          {},
	"i":             {},
	"url":           {},
	"gen":           {},
	"download-plan": {},
	"switch-plan":   {},
}

var legacyCommands = map[string]struct{}{
	"a":               {},
	"add":             {},
	"no-auto-tls":     {},
	"api":             {},
	"xapi":            {},
	"bin":             {},
	"convert":         {},
	"tls":             {},
	"run":             {},
	"uuid":            {},
	"bbr":             {},
	"c":               {},
	"config":          {},
	"change":          {},
	"client":          {},
	"genc":            {},
	"d":               {},
	"del":             {},
	"rm":              {},
	"dd":              {},
	"ddel":            {},
	"fix":             {},
	"fix-all":         {},
	"dns":             {},
	"debug":           {},
	"fix-config.json": {},
	"fix-caddyfile":   {},
	"fix-nginxfile":   {},
	"mihomo":          {},
	"clash":           {},
	"refresh-sub":     {},
	"sub-refresh":     {},
	"sub-url":         {},
	"ip":              {},
	"log":             {},
	"logerr":          {},
	"errlog":          {},
	"qr":              {},
	"un":              {},
	"uninstall":       {},
	"u":               {},
	"up":              {},
	"update":          {},
	"U":               {},
	"update.sh":       {},
	"ssss":            {},
	"ss2022":          {},
	"start":           {},
	"stop":            {},
	"r":               {},
	"restart":         {},
	"t":               {},
	"test":            {},
	"reinstall":       {},
	"get-port":        {},
	"main":            {},
	"h":               {},
	"help":            {},
	"--help":          {},
}

func IsMigrated(command string) bool {
	_, ok := migratedCommands[strings.TrimSpace(command)]
	return ok
}

func IsLegacy(command string) bool {
	_, ok := legacyCommands[strings.TrimSpace(command)]
	return ok
}

func Classify(command string) string {
	switch {
	case IsMigrated(command):
		return "migrated"
	case IsLegacy(command):
		return "legacy"
	default:
		return "unknown"
	}
}
