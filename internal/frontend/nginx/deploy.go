package nginx

import (
	"context"
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"

	"github.com/WangYan-Good/xray/internal/acme"
	"github.com/WangYan-Good/xray/internal/protocol"
	systemexec "github.com/WangYan-Good/xray/internal/system"
)

type DeployOptions struct {
	Root       string
	DryRun     bool
	Runner     systemexec.Runner
	ACME       acme.Config
	Warn       func(string)
	FileAction func(string)
}

type DeployResult struct {
	CertificateIssued bool
	RouteAdded        bool
	Idempotent        bool
}

type Deployer struct {
	options DeployOptions
}

func NewDeployer(options DeployOptions) (*Deployer, error) {
	if options.Runner == nil {
		return nil, fmt.Errorf("Nginx deployer requires a runner")
	}
	if options.Root == "" {
		options.Root = "/"
	}
	return &Deployer{options: options}, nil
}

func (d *Deployer) Deploy(ctx context.Context, profile protocol.Profile) (result DeployResult, retErr error) {
	if err := d.preflight(ctx, profile); err != nil {
		return result, err
	}
	domain := profile.Host
	sitePath := d.path(filepath.Join(SiteDir, domain+".conf"))
	addPath := sitePath + ".add"
	renewalPath := d.path(filepath.Join("/etc/letsencrypt/renewal", domain+".conf"))
	hookPath := d.path(DeployHookPath)
	tx, err := newFileTransaction(d.options.Root, d.options.DryRun)
	if err != nil {
		return result, err
	}
	defer tx.Close()
	for _, path := range []string{sitePath, addPath, renewalPath, hookPath} {
		if err := tx.Track(path); err != nil {
			return result, err
		}
	}
	preserveAfterIssue := make(map[string]bool)
	defer func() {
		if retErr == nil {
			return
		}
		rollbackErr := tx.Rollback(preserveAfterIssue)
		if rollbackErr == nil && !d.options.DryRun {
			if _, validateErr := d.run(ctx, ValidateCommand()); validateErr == nil {
				_, rollbackErr = d.run(ctx, ReloadCommand())
			}
		}
		if rollbackErr != nil {
			retErr = fmt.Errorf("%w; rollback failed: %v", retErr, rollbackErr)
		}
	}()

	originalSite, siteExists, err := readOptional(sitePath)
	if err != nil {
		return result, err
	}
	originalAdd, _, err := readOptional(addPath)
	if err != nil {
		return result, err
	}
	if siteExists {
		check, err := CheckAppend(string(originalSite), string(originalAdd), profile)
		if err != nil {
			return result, err
		}
		switch check.Status {
		case AppendConflict:
			return result, fmt.Errorf("Nginx route %s already maps to port %d, requested port %d", check.Path, check.ExistingPort, check.WantedPort)
		case AppendSame:
			result.Idempotent = true
		}
	}

	certificateValid, err := d.certificateValid(ctx, domain)
	if err != nil {
		d.warn(fmt.Sprintf("existing certificate is not usable and will be repaired: %v", err))
	}
	if !certificateValid {
		if err := d.options.ACME.Validate(); err != nil {
			return result, err
		}
		if err := d.installBootstrap(ctx, sitePath, domain); err != nil {
			return result, err
		}
		if _, err := d.run(ctx, CertbotIssueCommand(domain, d.options.ACME)); err != nil {
			return result, err
		}
		if !d.options.DryRun && d.options.Root == "/" {
			if err := d.verifyCertificateFiles(domain); err != nil {
				return result, err
			}
		}
		if err := d.verifyCertificateCommands(ctx, domain); err != nil {
			return result, err
		}
		result.CertificateIssued = true
		preserveAfterIssue[renewalPath] = true
	}

	finalSite, finalAdd, added, err := d.finalCandidates(profile, originalSite, originalAdd, siteExists, certificateValid || result.CertificateIssued, result.Idempotent)
	if err != nil {
		return result, err
	}
	result.RouteAdded = added
	if err := d.validateCandidates(ctx, sitePath, addPath, finalSite, finalAdd); err != nil {
		return result, err
	}
	if err := d.write(sitePath, finalSite, 0o644); err != nil {
		return result, err
	}
	if err := d.write(addPath, finalAdd, 0o644); err != nil {
		return result, err
	}
	if err := d.migrateRenewal(renewalPath, domain); err != nil {
		return result, err
	}
	if _, err := d.run(ctx, ValidateCommand()); err != nil {
		return result, err
	}
	if _, err := d.run(ctx, ReloadCommand()); err != nil {
		return result, err
	}
	if err := d.write(hookPath, []byte(DeployHook), 0o755); err != nil {
		return result, err
	}
	if err := d.ensureRenewalScheduler(ctx); err != nil {
		return result, err
	}
	if result.CertificateIssued {
		if _, err := d.run(ctx, CertbotRenewDryRunCommand()); err != nil {
			return result, err
		}
	}
	return result, nil
}

func (d *Deployer) preflight(ctx context.Context, profile protocol.Profile) error {
	if d.options.Root == "/" && os.Geteuid() != 0 {
		return fmt.Errorf("Nginx deployment must run as root")
	}
	if err := ValidateDomain(profile.Host); err != nil {
		return err
	}
	if err := ValidateBackendPort(profile.Port); err != nil {
		return err
	}
	for _, command := range []systemexec.Command{
		{Name: "nginx", Args: []string{"-v"}, Step: "check Nginx dependency"},
		{Name: "certbot", Args: []string{"--version"}, Step: "check Certbot dependency"},
		{Name: "openssl", Args: []string{"version"}, Step: "check OpenSSL dependency"},
		{Name: "systemctl", Args: []string{"--version"}, Step: "check systemd dependency"},
	} {
		if _, err := d.run(ctx, command); err != nil {
			return err
		}
	}
	ports, err := d.run(ctx, systemexec.Command{Name: "ss", Args: []string{"-ltnp"}, Step: "check TCP 80 and 443 listeners"})
	if err != nil {
		return err
	}
	if conflict := ConflictingListener(ports.Stdout); conflict != "" {
		return fmt.Errorf("TCP 80 or 443 is occupied by another service: %s", conflict)
	}
	if d.options.Root == "/" && !d.options.DryRun {
		if _, err := net.LookupIP(profile.Host); err != nil {
			d.warn(fmt.Sprintf("DNS lookup warning for %s: %v", profile.Host, err))
		}
	}
	if !d.options.DryRun {
		if err := os.MkdirAll(d.path(CertbotRoot), 0o755); err != nil {
			return err
		}
	}
	return nil
}

func ConflictingListener(output string) string {
	for _, line := range strings.Split(output, "\n") {
		if !strings.Contains(line, ":80 ") && !strings.Contains(line, ":80\n") && !strings.Contains(line, ":443 ") && !strings.Contains(line, ":443\n") && !strings.HasSuffix(strings.TrimSpace(line), ":80") && !strings.HasSuffix(strings.TrimSpace(line), ":443") {
			continue
		}
		if strings.Contains(strings.ToLower(line), "nginx") {
			continue
		}
		return strings.TrimSpace(line)
	}
	return ""
}

func (d *Deployer) certificateValid(ctx context.Context, domain string) (bool, error) {
	if err := d.verifyCertificateFiles(domain); err != nil {
		return false, nil
	}
	if err := d.verifyCertificateCommands(ctx, domain); err != nil {
		return false, err
	}
	return true, nil
}

func (d *Deployer) verifyCertificateFiles(domain string) error {
	for _, path := range []string{d.path(CertificatePath(domain)), d.path(PrivateKeyPath(domain))} {
		info, err := os.Stat(path)
		if err != nil {
			return fmt.Errorf("certificate file %s: %w", path, err)
		}
		if info.Size() == 0 {
			return fmt.Errorf("certificate file is empty: %s", path)
		}
	}
	return nil
}

func (d *Deployer) verifyCertificateCommands(ctx context.Context, domain string) error {
	commands := []systemexec.Command{
		certificateCommandForPath(d.path(CertificatePath(domain))),
		privateKeyCommandForPath(d.path(PrivateKeyPath(domain))),
		certificateExpiryCommandForPath(d.path(CertificatePath(domain))),
		certificateHostCommandForPath(d.path(CertificatePath(domain)), domain),
	}
	for _, command := range commands {
		if _, err := d.run(ctx, command); err != nil {
			return err
		}
	}
	return nil
}

func (d *Deployer) installBootstrap(ctx context.Context, sitePath, domain string) error {
	bootstrap, err := RenderBootstrap(domain)
	if err != nil {
		return err
	}
	if err := d.validateCandidates(ctx, sitePath, sitePath+".add", []byte(bootstrap), nil); err != nil {
		return err
	}
	if err := d.write(sitePath, []byte(bootstrap), 0o644); err != nil {
		return err
	}
	if _, err := d.run(ctx, ValidateCommand()); err != nil {
		return err
	}
	_, err = d.run(ctx, ReloadCommand())
	return err
}

func (d *Deployer) finalCandidates(profile protocol.Profile, originalSite, originalAdd []byte, siteExists, certificateVerified, idempotent bool) ([]byte, []byte, bool, error) {
	if !siteExists || !strings.Contains(string(originalSite), "listen 443") {
		site, err := RenderSite(profile)
		if err != nil {
			return nil, nil, false, err
		}
		return []byte(site), originalAdd, true, nil
	}
	site, _, warning := MigrateCertificatePaths(string(originalSite), profile.Host, certificateVerified)
	if warning != "" {
		d.warn(warning)
	}
	if idempotent {
		return []byte(site), originalAdd, false, nil
	}
	route, err := RenderAdd(profile)
	if err != nil {
		return nil, nil, false, err
	}
	add := appendOnceText(string(originalAdd), route)
	return []byte(site), []byte(add), add != string(originalAdd), nil
}

func (d *Deployer) validateCandidates(ctx context.Context, sitePath, addPath string, site, add []byte) error {
	if d.options.DryRun {
		_, err := d.run(ctx, systemexec.Command{Name: "nginx", Args: []string{"-t", "-c", "/tmp/xray-nginx-shadow.conf"}, Step: "validate staged Nginx configuration"})
		return err
	}
	dir := filepath.Dir(sitePath)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	candidateSite, err := os.CreateTemp(dir, ".xray-site-candidate-*")
	if err != nil {
		return err
	}
	candidateSitePath := candidateSite.Name()
	candidateSite.Close()
	defer os.Remove(candidateSitePath)
	candidateAdd, err := os.CreateTemp(dir, ".xray-add-candidate-*")
	if err != nil {
		return err
	}
	candidateAddPath := candidateAdd.Name()
	candidateAdd.Close()
	defer os.Remove(candidateAddPath)
	if err := os.WriteFile(candidateAddPath, add, 0o644); err != nil {
		return err
	}
	candidateText := strings.ReplaceAll(string(site), canonicalPath(addPath, d.options.Root), candidateAddPath)
	if err := os.WriteFile(candidateSitePath, []byte(candidateText), 0o644); err != nil {
		return err
	}
	tmpDir := d.path("/tmp")
	shadow, err := os.CreateTemp(tmpDir, "xray-nginx-shadow-*.conf")
	if err != nil {
		return err
	}
	shadowPath := shadow.Name()
	defer os.Remove(shadowPath)
	content := fmt.Sprintf("events {}\nhttp {\n    include %s;\n}\n", candidateSitePath)
	if _, err := shadow.WriteString(content); err != nil {
		shadow.Close()
		return err
	}
	if err := shadow.Close(); err != nil {
		return err
	}
	_, err = d.run(ctx, systemexec.Command{Name: "nginx", Args: []string{"-t", "-c", shadowPath}, Step: "validate staged Nginx configuration"})
	return err
}

func (d *Deployer) migrateRenewal(path, domain string) error {
	data, exists, err := readOptional(path)
	if err != nil || !exists {
		return err
	}
	repaired, changed := EnsureWebrootRenewal(string(data), domain)
	repaired, installerChanged := RemoveNginxInstaller(repaired)
	if !changed && !installerChanged {
		return nil
	}
	return d.write(path, []byte(repaired), 0o600)
}

func (d *Deployer) ensureRenewalScheduler(ctx context.Context) error {
	result, err := d.run(ctx, systemexec.Command{Name: "systemctl", Args: []string{"list-unit-files", "certbot.timer", "certbot-renew.timer", "--no-legend"}, Step: "detect Certbot timer"})
	if timer := RenewalTimerFromUnitFiles(result.Stdout); err == nil && timer != "" {
		_, err = d.run(ctx, systemexec.Command{Name: "systemctl", Args: []string{"enable", "--now", timer}, Step: "enable Certbot timer"})
		return err
	}
	if _, statErr := os.Stat(d.path("/etc/cron.d/certbot")); statErr == nil {
		return nil
	}
	d.warn("Certbot automatic renewal timer or cron job was not found")
	return nil
}

// RenewalTimerFromUnitFiles supports both the Debian/Ubuntu Certbot timer and
// the certbot-renew timer shipped by RHEL-compatible distributions.
func RenewalTimerFromUnitFiles(output string) string {
	for _, timer := range []string{"certbot.timer", "certbot-renew.timer"} {
		if strings.Contains(output, timer) {
			return timer
		}
	}
	return ""
}

func (d *Deployer) write(path string, data []byte, mode os.FileMode) error {
	d.fileAction(fmt.Sprintf("write %s mode %04o", path, mode))
	if d.options.DryRun {
		return nil
	}
	return atomicWriteFile(path, data, mode)
}

func (d *Deployer) run(ctx context.Context, command systemexec.Command) (systemexec.Result, error) {
	return d.options.Runner.Run(ctx, command)
}

func (d *Deployer) path(path string) string { return rootedPath(d.options.Root, path) }

func (d *Deployer) warn(message string) {
	if d.options.Warn != nil {
		d.options.Warn(message)
	}
}

func (d *Deployer) fileAction(message string) {
	if d.options.FileAction != nil {
		d.options.FileAction(message)
	}
}

func readOptional(path string) ([]byte, bool, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil, false, nil
	}
	return data, err == nil, err
}

func appendOnceText(content, addition string) string {
	if strings.Contains(content, strings.TrimSpace(addition)) {
		return content
	}
	if content != "" && !strings.HasSuffix(content, "\n") {
		content += "\n"
	}
	content += addition
	if !strings.HasSuffix(content, "\n") {
		content += "\n"
	}
	return content
}

func canonicalPath(rooted string, root string) string {
	if root == "" || root == "/" {
		return rooted
	}
	prefix := strings.TrimSuffix(root, "/")
	return strings.TrimPrefix(rooted, prefix)
}

func certificateCommandForPath(path string) systemexec.Command {
	return systemexec.Command{Name: "openssl", Args: []string{"x509", "-in", path, "-noout"}, Step: "parse TLS certificate"}
}

func privateKeyCommandForPath(path string) systemexec.Command {
	return systemexec.Command{Name: "openssl", Args: []string{"pkey", "-in", path, "-noout"}, Step: "parse TLS private key"}
}

func certificateExpiryCommandForPath(path string) systemexec.Command {
	return systemexec.Command{Name: "openssl", Args: []string{"x509", "-in", path, "-noout", "-checkend", "0"}, Step: "check TLS certificate expiry"}
}

func certificateHostCommandForPath(path, domain string) systemexec.Command {
	return systemexec.Command{Name: "openssl", Args: []string{"x509", "-in", path, "-noout", "-checkhost", domain}, Step: "check TLS certificate domain"}
}
