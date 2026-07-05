package legacy

import (
	"fmt"
	"strings"
)

type SwitchPlan struct {
	Mode            string
	EntryPath       string
	GoTarget        string
	LegacyPath      string
	RollbackCommand string
	Steps           []string
}

func NewSwitchPlan(mode string) SwitchPlan {
	mode = strings.ToLower(strings.TrimSpace(mode))
	if mode == "" {
		mode = "go"
	}
	plan := SwitchPlan{
		Mode:            mode,
		EntryPath:       "/usr/local/bin/xray",
		GoTarget:        "/usr/local/bin/xray",
		LegacyPath:      DefaultPath,
		RollbackCommand: "ln -sf /etc/xray/sh/xray.sh /usr/local/bin/xray",
	}
	switch mode {
	case "rollback":
		plan.Steps = []string{
			"verify /etc/xray/sh/xray.sh exists",
			"replace /usr/local/bin/xray with symlink to /etc/xray/sh/xray.sh",
			"run xray version through Bash entry",
		}
	default:
		plan.Mode = "go"
		plan.Steps = []string{
			"download xray-linux-${arch}.tar.gz from release",
			"verify tarball with checksums.txt",
			"extract Go binary",
			"install Go binary to /usr/local/bin/xray",
			"keep /etc/xray/sh/xray.sh as legacy entry",
			"delegate unmigrated commands through /etc/xray/sh/xray.sh",
		}
	}
	return plan
}

func FormatSwitchPlan(plan SwitchPlan) string {
	var b strings.Builder
	fmt.Fprintf(&b, "mode = %s\n", plan.Mode)
	fmt.Fprintf(&b, "entry = %s\n", plan.EntryPath)
	fmt.Fprintf(&b, "go_target = %s\n", plan.GoTarget)
	fmt.Fprintf(&b, "legacy = %s\n", plan.LegacyPath)
	fmt.Fprintf(&b, "rollback = %s\n", plan.RollbackCommand)
	for i, step := range plan.Steps {
		fmt.Fprintf(&b, "step.%d = %s\n", i, step)
	}
	return b.String()
}
