package download

import (
	"fmt"
	"strings"
)

type Arch struct {
	Machine string
	Go      string
	Xray    string
	Caddy   string
	JQ      string
}

func NormalizeArch(machine string) (Arch, error) {
	machine = strings.ToLower(strings.TrimSpace(machine))
	switch {
	case machine == "amd64" || machine == "x86_64":
		return Arch{
			Machine: machine,
			Go:      "amd64",
			Xray:    "64",
			Caddy:   "amd64",
			JQ:      "amd64",
		}, nil
	case machine == "arm64" || machine == "aarch64" || strings.HasPrefix(machine, "armv8"):
		return Arch{
			Machine: machine,
			Go:      "arm64",
			Xray:    "arm64-v8a",
			Caddy:   "arm64",
			JQ:      "arm64",
		}, nil
	default:
		return Arch{}, fmt.Errorf("unsupported architecture: %s", machine)
	}
}
