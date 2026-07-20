package system

import (
	"context"
	"fmt"
	"os"
	"os/exec"
)

var nginxRequiredCommands = []string{"nginx", "certbot", "openssl", "systemctl", "ss"}

type PackageInstaller struct {
	Runner   Runner
	Root     string
	LookPath func(string) bool
}

func (i PackageInstaller) EnsureNginxDependencies(ctx context.Context, proxy string) error {
	if i.Runner == nil {
		return fmt.Errorf("package installer requires a runner")
	}
	lookPath := i.LookPath
	if lookPath == nil {
		lookPath = func(name string) bool {
			_, err := exec.LookPath(name)
			return err == nil
		}
	}
	missing := make([]string, 0, len(nginxRequiredCommands))
	for _, name := range nginxRequiredCommands {
		if !lookPath(name) {
			missing = append(missing, name)
		}
	}
	if len(missing) == 0 {
		return nil
	}

	manager := ""
	for _, candidate := range []string{"apt-get", "dnf", "yum"} {
		if lookPath(candidate) {
			manager = candidate
			break
		}
	}
	if manager == "" {
		return fmt.Errorf("unsupported system: apt-get, dnf, or yum is required")
	}
	osReleasePath := rooted(i.Root, "/etc/os-release")
	data, err := os.ReadFile(osReleasePath)
	if err != nil {
		return fmt.Errorf("read %s: %w", osReleasePath, err)
	}
	plan, err := NginxPackagePlan(ParseOSRelease(string(data)), manager, proxy, missing)
	if err != nil {
		return err
	}
	for _, command := range []*Command{plan.Update, plan.EnableEPEL, &plan.Install} {
		if command == nil || command.Name == "" {
			continue
		}
		if _, err := i.Runner.Run(ctx, *command); err != nil {
			return err
		}
	}

	for _, name := range missing {
		command := versionCommand(name)
		if _, err := i.Runner.Run(ctx, command); err != nil {
			return fmt.Errorf("dependency %s is unavailable after installation: %w", name, err)
		}
	}
	return nil
}

func versionCommand(name string) Command {
	args := []string{"--version"}
	switch name {
	case "nginx":
		args = []string{"-v"}
	case "openssl":
		args = []string{"version"}
	case "ss":
		args = []string{"-V"}
	}
	return Command{Name: name, Args: args, Step: "verify " + name + " dependency"}
}

func rooted(root, path string) string {
	if root == "" || root == "/" {
		return path
	}
	return root + path
}
