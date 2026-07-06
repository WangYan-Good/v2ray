package caddy

import "github.com/WangYan-Good/xray/internal/frontend"

func ValidateCommand() frontend.Command {
	return frontend.Command{Name: "caddy", Args: []string{"validate", "--config", DefaultCaddyfile, "--adapter", "caddyfile"}}
}

func ReloadCommand() frontend.Command {
	return frontend.Command{Name: "systemctl", Args: []string{"reload", "caddy"}}
}

func OperationPlan() []frontend.Command {
	return []frontend.Command{
		ValidateCommand(),
		ReloadCommand(),
	}
}
