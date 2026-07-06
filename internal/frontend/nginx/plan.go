package nginx

import "github.com/WangYan-Good/xray/internal/frontend"

func ValidateCommand() frontend.Command {
	return frontend.Command{Name: "nginx", Args: []string{"-t"}}
}

func ReloadCommand() frontend.Command {
	return frontend.Command{Name: "systemctl", Args: []string{"reload", "nginx"}}
}

func CertbotIssueCommand(domain string) frontend.Command {
	return frontend.Command{Name: "certbot", Args: []string{"certonly", "--webroot", "-w", CertbotRoot, "-d", domain}}
}

func CertbotRenewDryRunCommand() frontend.Command {
	return frontend.Command{Name: "certbot", Args: []string{"renew", "--dry-run", "--deploy-hook", "systemctl reload nginx"}}
}

func OperationPlan(domain string) []frontend.Command {
	return []frontend.Command{
		ValidateCommand(),
		CertbotIssueCommand(domain),
		CertbotRenewDryRunCommand(),
		ReloadCommand(),
	}
}
