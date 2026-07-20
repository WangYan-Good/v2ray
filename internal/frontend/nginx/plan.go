package nginx

import (
	"github.com/WangYan-Good/xray/internal/acme"
	"github.com/WangYan-Good/xray/internal/frontend"
)

func ValidateCommand() frontend.Command {
	return frontend.Command{Name: "nginx", Args: []string{"-t"}}
}

func ReloadCommand() frontend.Command {
	return frontend.Command{Name: "systemctl", Args: []string{"reload", "nginx"}}
}

func CertbotIssueCommand(domain string, configs ...acme.Config) frontend.Command {
	args := []string{
		"certonly", "--webroot", "-w", CertbotRoot, "-d", domain,
		"--cert-name", domain, "--non-interactive", "--agree-tos", "--keep-until-expiring",
	}
	if len(configs) > 0 {
		if configs[0].Email != "" {
			args = append(args, "--email", configs[0].Email)
		} else if configs[0].NoEmail {
			args = append(args, "--register-unsafely-without-email")
		}
	}
	return frontend.Command{Name: "certbot", Args: args, Step: "issue TLS certificate"}
}

func CertbotRenewDryRunCommand() frontend.Command {
	return frontend.Command{Name: "certbot", Args: []string{"renew", "--dry-run"}, Step: "test certificate renewal"}
}

func CertificateCommand(domain string) frontend.Command {
	return frontend.Command{Name: "openssl", Args: []string{"x509", "-in", CertificatePath(domain), "-noout"}, Step: "parse TLS certificate"}
}

func CertificateExpiryCommand(domain string) frontend.Command {
	return frontend.Command{Name: "openssl", Args: []string{"x509", "-in", CertificatePath(domain), "-noout", "-checkend", "0"}, Step: "check TLS certificate expiry"}
}

func CertificateHostCommand(domain string) frontend.Command {
	return frontend.Command{Name: "openssl", Args: []string{"x509", "-in", CertificatePath(domain), "-noout", "-checkhost", domain}, Step: "check TLS certificate domain"}
}

func PrivateKeyCommand(domain string) frontend.Command {
	return frontend.Command{Name: "openssl", Args: []string{"pkey", "-in", PrivateKeyPath(domain), "-noout"}, Step: "parse TLS private key"}
}

func OperationPlan(domain string) []frontend.Command {
	return []frontend.Command{
		ValidateCommand(),
		CertbotIssueCommand(domain),
		CertbotRenewDryRunCommand(),
		ReloadCommand(),
	}
}
