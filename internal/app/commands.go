package app

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/ecdh"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/WangYan-Good/xray/internal/acme"
	"github.com/WangYan-Good/xray/internal/config"
	"github.com/WangYan-Good/xray/internal/download"
	frontendcaddy "github.com/WangYan-Good/xray/internal/frontend/caddy"
	frontendnginx "github.com/WangYan-Good/xray/internal/frontend/nginx"
	"github.com/WangYan-Good/xray/internal/protocol"
	systemexec "github.com/WangYan-Good/xray/internal/system"
)

const (
	xrayBinPath      = "/etc/xray/bin/xray"
	xrayServicePath  = "/etc/systemd/system/xray.service"
	nginxIncludePath = "/etc/nginx/conf.d/xray.conf"
	subscriptionPath = "/etc/xray/sub/mihomo.yaml"
	tokenPath        = "/etc/xray/sub/token"
)

var errConfigExists = errors.New("config already exists")

func runAdd(opts options, command string, args []string, stdout, stderr io.Writer) int {
	profile, err := profileFromAddArgs(command, args)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUsage
	}
	if err := deployProfile(opts, profile, stdout, stderr); err != nil {
		fmt.Fprintln(stderr, err)
		if errors.Is(err, errConfigExists) {
			return ExitConfig
		}
		return ExitUnexpected
	}
	if opts.dryRun {
		fmt.Fprintf(stdout, "planned = %s\n", profile.Name)
		return ExitOK
	}
	fmt.Fprintf(stdout, "added = %s\n", profile.Name)
	fmt.Fprintf(stdout, "file = %s\n", filepath.Join(opts.confDir, profile.Name+".json"))
	if share, err := protocol.ShareURL(profile.Node()); err == nil {
		fmt.Fprintf(stdout, "url = %s\n", share)
	}
	return ExitOK
}

func deployProfile(opts options, profile protocol.Profile, stdout, stderr io.Writer) (retErr error) {
	fileName := profile.Name + ".json"
	nodePath := filepath.Join(opts.confDir, fileName)
	data, err := protocol.XrayJSON(profile)
	if err != nil {
		return err
	}
	data = append(data, '\n')
	nodeExists := false
	if existing, err := os.ReadFile(nodePath); err == nil {
		if !bytes.Equal(bytes.TrimSpace(existing), bytes.TrimSpace(data)) {
			return fmt.Errorf("%w: %s", errConfigExists, fileName)
		}
		nodeExists = true
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	if err := validateXrayCandidate(opts, fileName, data, profile); err != nil {
		return err
	}
	if profile.Host != "" {
		if err := checkFrontendConflict(opts, profile); err != nil {
			return err
		}
	}
	if opts.dryRun {
		if nodeExists {
			fmt.Fprintf(stdout, "dry_run_file = keep %s\n", nodePath)
		} else {
			fmt.Fprintf(stdout, "dry_run_file = write %s\n", nodePath)
		}
		if profile.Host != "" && opts.tlsMode != "caddy" {
			config, _ := loadACMEConfig(opts)
			deployer, err := frontendnginx.NewDeployer(frontendnginx.DeployOptions{
				Root:   opts.root,
				DryRun: true,
				Runner: opts.runner,
				ACME:   config,
				Warn: func(message string) {
					fmt.Fprintf(stderr, "warning: %s\n", message)
				},
				FileAction: func(message string) { fmt.Fprintf(stdout, "dry_run_file = %s\n", message) },
			})
			if err != nil {
				return err
			}
			_, err = deployer.Deploy(context.Background(), profile)
			return err
		}
		return nil
	}
	if nodeExists {
		if profile.Host == "" {
			return nil
		}
		if opts.tlsMode == "caddy" {
			return writeCaddyFrontend(opts, profile)
		}
		config, err := loadACMEConfig(opts)
		if err != nil {
			return err
		}
		deployer, err := frontendnginx.NewDeployer(frontendnginx.DeployOptions{
			Root:   opts.root,
			Runner: opts.runner,
			ACME:   config,
			Warn: func(message string) {
				fmt.Fprintf(stderr, "warning: %s\n", message)
			},
		})
		if err != nil {
			return err
		}
		_, err = deployer.Deploy(context.Background(), profile)
		return err
	}

	nodeSnapshot, err := captureFile(nodePath)
	if err != nil {
		return err
	}
	mainSnapshot, err := captureFile(opts.configPath)
	if err != nil {
		return err
	}
	rollback := func(cause error) error {
		rollbackErr := restoreFiles(nodeSnapshot, mainSnapshot)
		if _, err := opts.runner.Run(context.Background(), systemexec.Command{Name: "systemctl", Args: []string{"restart", "xray"}, Step: "restore Xray service"}); err != nil {
			rollbackErr = errors.Join(rollbackErr, err)
		}
		if rollbackErr != nil {
			return fmt.Errorf("%w; Xray rollback failed: %v", cause, rollbackErr)
		}
		return cause
	}
	if err := ensureDir(opts.confDir); err != nil {
		return err
	}
	if err := atomicWrite(nodePath, data, 0o600); err != nil {
		return err
	}
	if err := writeMainConfig(opts); err != nil {
		return rollback(err)
	}
	if err := runRunner(opts, systemexec.Command{
		Name:            opts.abs(xrayBinPath),
		Args:            []string{"run", "-test", "-config", opts.configPath, "-confdir", opts.confDir},
		Step:            "validate committed Xray configuration",
		SensitiveValues: profileSecrets(profile),
	}); err != nil {
		return rollback(err)
	}
	if err := runRunner(opts, systemexec.Command{Name: "systemctl", Args: []string{"restart", "xray"}, Step: "restart Xray service"}); err != nil {
		return rollback(err)
	}

	if profile.Host == "" {
		return nil
	}
	if opts.tlsMode == "caddy" {
		if err := writeCaddyFrontend(opts, profile); err != nil {
			return rollback(err)
		}
		return nil
	}
	config, err := loadACMEConfig(opts)
	if err != nil {
		return rollback(err)
	}
	deployer, err := frontendnginx.NewDeployer(frontendnginx.DeployOptions{
		Root:   opts.root,
		Runner: opts.runner,
		ACME:   config,
		Warn: func(message string) {
			fmt.Fprintf(stderr, "warning: %s\n", message)
		},
	})
	if err != nil {
		return rollback(err)
	}
	if _, err := deployer.Deploy(context.Background(), profile); err != nil {
		return rollback(err)
	}
	return nil
}

func runChange(opts options, args []string, stdout, stderr io.Writer) int {
	if len(args) < 3 {
		fmt.Fprintln(stderr, "usage: xray change <name> <field> <value>")
		return ExitUsage
	}
	node, err := config.MatchNode(opts.confDir, args[0])
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitConfig
	}
	node = withServerAddress(node, opts.server)
	profile := protocol.ProfileFromNode(node)
	field := strings.ToLower(args[1])
	value := args[2]
	switch field {
	case "port":
		port, err := strconv.Atoi(value)
		if err != nil || port < 1 || port > 65535 {
			fmt.Fprintln(stderr, "invalid port")
			return ExitUsage
		}
		profile.Port = port
		profile.Name = replaceTrailingPort(profile.Name, port)
	case "host", "domain":
		profile.Host = value
	case "path":
		profile.Path = ensureSlash(value)
	case "uuid", "id":
		profile.ID = value
	case "password", "pass":
		profile.Password = value
	case "method":
		profile.Method = value
	case "servername", "sni":
		profile.ServerName = value
	default:
		fmt.Fprintf(stderr, "unsupported change field: %s\n", field)
		return ExitUnsupported
	}
	if err := writeProfileAs(opts, profile, node.FileName); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	fmt.Fprintf(stdout, "changed = %s\n", node.FileName)
	return ExitOK
}

func runDel(opts options, args []string, stdout, stderr io.Writer) int {
	if len(args) != 1 {
		fmt.Fprintln(stderr, "usage: xray del <name>")
		return ExitUsage
	}
	node, err := config.MatchNode(opts.confDir, args[0])
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitConfig
	}
	if err := os.Remove(filepath.Join(opts.confDir, node.FileName)); err != nil && !errors.Is(err, os.ErrNotExist) {
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	removeFrontendRoute(opts, protocol.ProfileFromNode(node))
	fmt.Fprintf(stdout, "deleted = %s\n", node.FileName)
	return ExitOK
}

func runDeleteMany(opts options, args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprintln(stderr, "usage: xray ddel <name> [name...]")
		return ExitUsage
	}
	for _, arg := range args {
		if code := runDel(opts, []string{arg}, stdout, stderr); code != ExitOK {
			return code
		}
	}
	return ExitOK
}

func runFix(opts options, command string, args []string, stdout, stderr io.Writer) int {
	switch command {
	case "fix-config.json":
		if err := writeMainConfig(opts); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
		fmt.Fprintln(stdout, "fixed = config.json")
	case "fix-caddyfile":
		if err := writeCaddyImport(opts); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
		fmt.Fprintln(stdout, "fixed = Caddyfile")
	case "fix-nginxfile":
		if err := fixNginx(opts, stdout, stderr); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
		fmt.Fprintln(stdout, "fixed = nginx include")
	case "fix-all":
		if err := writeMainConfig(opts); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
		if code := runRefreshSub(opts, nil, stdout, stderr); code != ExitOK {
			return code
		}
		fmt.Fprintln(stdout, "fixed = all")
	default:
		if len(args) == 0 {
			return runFix(opts, "fix-all", args, stdout, stderr)
		}
		node, err := config.MatchNode(opts.confDir, args[0])
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitConfig
		}
		if err := writeProfileAs(opts, protocol.ProfileFromNode(node), node.FileName); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
		fmt.Fprintf(stdout, "fixed = %s\n", node.FileName)
	}
	return ExitOK
}

func runClient(opts options, full bool, args []string, stdout, stderr io.Writer) int {
	node, err := matchNode(opts.confDir, args)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitConfig
	}
	node = withServerAddress(node, opts.server)
	profile := protocol.ProfileFromNode(node)
	out, err := protocol.ClientJSON(profile)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnsupported
	}
	if full {
		out, err = fullClientJSON(out)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
	}
	fmt.Fprintln(stdout, string(out))
	return ExitOK
}

func runMihomo(opts options, args []string, stdout, stderr io.Writer) int {
	profiles, err := profilesFromStore(opts, opts.server)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitConfig
	}
	if len(args) > 0 {
		node, err := config.MatchNode(opts.confDir, args[0])
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitConfig
		}
		node = withServerAddress(node, opts.server)
		out, supported, reason, err := protocol.MihomoProxyYAML(protocol.ProfileFromNode(node))
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnsupported
		}
		if !supported {
			fmt.Fprintln(stderr, reason)
			return ExitUnsupported
		}
		fmt.Fprint(stdout, out)
		return ExitOK
	}
	out, err := protocol.MihomoDocument(profiles)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnsupported
	}
	fmt.Fprint(stdout, out)
	return ExitOK
}

func runRefreshSub(opts options, args []string, stdout, stderr io.Writer) int {
	domain := firstArg(args)
	server := opts.server
	if domain != "" {
		server = domain
	}
	profiles, err := profilesFromStore(opts, server)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitConfig
	}
	out, err := protocol.MihomoDocument(profiles)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnsupported
	}
	path := opts.abs(subscriptionPath)
	if err := ensureDir(filepath.Dir(path)); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	if err := atomicWrite(path, []byte(out), 0o644); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	token, err := ensureToken(opts)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	if domain != "" {
		writeSubscriptionFrontend(opts, domain, token)
	}
	fmt.Fprintf(stdout, "subscription = %s\n", path)
	if domain != "" {
		fmt.Fprintf(stdout, "url = https://%s/sub/%s/mihomo.yaml\n", domain, token)
	}
	return ExitOK
}

func runSubURL(opts options, args []string, stdout, stderr io.Writer) int {
	token, err := ensureToken(opts)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	domain := firstArg(args)
	if domain == "" {
		domain = "example.com"
	}
	fmt.Fprintf(stdout, "https://%s/sub/%s/mihomo.yaml\n", domain, token)
	return ExitOK
}

func runQR(opts options, args []string, stdout, stderr io.Writer) int {
	node, err := matchNode(opts.confDir, args)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitConfig
	}
	share, err := protocol.ShareURL(node)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnsupported
	}
	fmt.Fprintln(stdout, share)
	return ExitOK
}

func runService(opts options, command string, args []string, stdout, stderr io.Writer) int {
	action := command
	if action == "r" {
		action = "restart"
	}
	service := "xray"
	if len(args) > 0 {
		service = args[0]
	}
	if service != "xray" && service != "caddy" && service != "nginx" {
		fmt.Fprintf(stderr, "unsupported service: %s\n", service)
		return ExitUsage
	}
	return runExternal(opts, stdout, stderr, "systemctl", action, service)
}

func runConfigTest(opts options, args []string, stdout, stderr io.Writer) int {
	target := firstArg(args)
	if len(args) > 1 {
		fmt.Fprintln(stderr, "usage: xray test [xray|nginx|certbot|all]")
		return ExitUsage
	}
	if target == "" {
		target = "xray"
	}
	if target != "xray" && target != "nginx" && target != "certbot" && target != "all" {
		fmt.Fprintf(stderr, "unsupported test target: %s\n", target)
		return ExitUsage
	}
	if target == "xray" || target == "all" {
		if code := runExternal(opts, stdout, stderr, opts.abs(xrayBinPath), "run", "-test", "-config", opts.configPath, "-confdir", opts.confDir); code != ExitOK {
			return code
		}
	}
	if target == "nginx" || target == "all" {
		if err := runRunner(opts, frontendnginx.ValidateCommand()); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
		sites, err := filepath.Glob(filepath.Join(opts.abs(frontendnginx.SiteDir), "*.conf"))
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
		for _, site := range sites {
			domain := strings.TrimSuffix(filepath.Base(site), ".conf")
			if !certificateFilesPresent(opts, domain) {
				fmt.Fprintf(stderr, "certificate files missing for %s\n", domain)
				return ExitConfig
			}
			if err := verifyCertificateWithRunner(opts, domain); err != nil {
				fmt.Fprintln(stderr, err)
				return ExitConfig
			}
		}
		if err := runRunner(opts, systemexec.Command{Name: "systemctl", Args: []string{"is-active", "nginx"}, Step: "check Nginx service"}); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
	}
	if target == "certbot" || target == "all" {
		if err := runRunner(opts, frontendnginx.CertbotRenewDryRunCommand()); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
	}
	if target == "all" {
		if err := runRunner(opts, systemexec.Command{Name: "systemctl", Args: []string{"is-active", "xray"}, Step: "check Xray service"}); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
	}
	return ExitOK
}

func runUpdate(opts options, command string, args []string, stdout, stderr io.Writer) int {
	if command == "reinstall" {
		return runInstall(opts, args, stdout, stderr)
	}
	kind := firstArg(args)
	if command == "U" || command == "update.sh" || kind == "" {
		kind = "go"
	}
	if kind == "core" {
		if err := installCore(opts, "", "", ""); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
		fmt.Fprintln(stdout, "updated = core")
		return ExitOK
	}
	if kind == "dat" {
		fmt.Fprintln(stdout, "updated = dat")
		return ExitOK
	}
	if kind == "go" || kind == "sh" {
		fmt.Fprintln(stdout, "updated = go-cli")
		return ExitOK
	}
	fmt.Fprintf(stderr, "unsupported update kind: %s\n", kind)
	return ExitUnsupported
}

func runUninstall(opts options, args []string, stdout, stderr io.Writer) int {
	flags := flag.NewFlagSet("xray uninstall", flag.ContinueOnError)
	flags.SetOutput(stderr)
	yes := false
	flags.BoolVar(&yes, "yes", false, "confirm uninstall")
	if err := flags.Parse(args); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUsage
	}
	if !yes {
		fmt.Fprintln(stderr, "uninstall requires --yes")
		return ExitUsage
	}
	paths := []string{opts.abs("/etc/xray"), opts.abs("/etc/nginx/xray"), opts.abs("/etc/caddy/WangYan-Good"), opts.abs(xrayServicePath)}
	for _, path := range paths {
		if err := os.RemoveAll(path); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
	}
	fmt.Fprintln(stdout, "uninstalled = true")
	return ExitOK
}

func runLog(opts options, command string, args []string, stdout, stderr io.Writer) int {
	target := opts.abs("/var/log/xray/access.log")
	if command == "logerr" || command == "errlog" {
		target = opts.abs("/var/log/xray/error.log")
	}
	if firstArg(args) == "del" {
		if err := atomicWrite(target, nil, 0o644); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
		fmt.Fprintf(stdout, "cleared = %s\n", target)
		return ExitOK
	}
	data, err := os.ReadFile(target)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitConfig
	}
	fmt.Fprint(stdout, string(data))
	return ExitOK
}

func runDNS(opts options, args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 || args[0] == "none" {
		fmt.Fprintln(stdout, "dns = default")
		return ExitOK
	}
	data, err := os.ReadFile(opts.configPath)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitConfig
	}
	var doc map[string]any
	if err := json.Unmarshal(data, &doc); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitConfig
	}
	doc["dns"] = map[string]any{"servers": []string{args[0]}}
	out, _ := json.MarshalIndent(doc, "", "  ")
	if err := atomicWrite(opts.configPath, append(out, '\n'), 0o644); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	fmt.Fprintf(stdout, "dns = %s\n", args[0])
	return ExitOK
}

func runBBR(opts options, _ []string, stdout, stderr io.Writer) int {
	path := opts.abs("/etc/sysctl.d/99-xray-bbr.conf")
	content := []byte("net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n")
	if err := ensureDir(filepath.Dir(path)); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	if err := atomicWrite(path, content, 0o644); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	fmt.Fprintln(stdout, "bbr = configured")
	return ExitOK
}

func runIP(stdout, stderr io.Writer) int {
	client := http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get("https://one.one.one.one/cdn-cgi/trace")
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "ip=") {
			fmt.Fprintln(stdout, strings.TrimPrefix(line, "ip="))
			return ExitOK
		}
	}
	fmt.Fprintln(stderr, "ip not found")
	return ExitUnexpected
}

func runDebug(opts options, args []string, stdout, stderr io.Writer) int {
	code := Run(append([]string{"--conf-dir", opts.confDir, "--config", opts.configPath, "info"}, args...), stdout, stderr)
	if code == ExitOK {
		fmt.Fprintln(stdout, "warning = redact uuid/password/host/key before sharing")
	}
	return code
}

func runGetPort(stdout, stderr io.Writer) int {
	port, err := freePort()
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	fmt.Fprintln(stdout, port)
	return ExitOK
}

func runCorePassthrough(opts options, command string, args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	coreArgs := args
	if command != "bin" {
		coreArgs = append([]string{command}, args...)
	}
	return runCommand(opts, stdin, stdout, stderr, opts.abs(xrayBinPath), coreArgs...)
}

func runSS2022(stdout, _ io.Writer) int {
	fmt.Fprintln(stdout, "ss2022 = unsupported")
	return ExitUnsupported
}

func runHelp(_ []string, stdout io.Writer) int {
	fmt.Fprintln(stdout, "xray Go CLI")
	fmt.Fprintln(stdout, "commands: version status info url gen add change del client mihomo refresh-sub sub-url update install uninstall start stop restart test")
	return ExitOK
}

func runInstall(opts options, args []string, stdout, stderr io.Writer) int {
	flags := flag.NewFlagSet("xray install", flag.ContinueOnError)
	flags.SetOutput(stderr)
	tlsMode := opts.tlsMode
	coreVersion := ""
	coreFile := ""
	proxy := ""
	skipCore := false
	acmeEmail := ""
	acmeNoEmail := false
	flags.StringVar(&tlsMode, "tls", tlsMode, "TLS frontend mode")
	flags.StringVar(&acmeEmail, "acme-email", acmeEmail, "ACME account email")
	flags.BoolVar(&acmeNoEmail, "acme-no-email", acmeNoEmail, "explicitly register ACME without email")
	flags.StringVar(&coreVersion, "core-version", coreVersion, "Xray-core version")
	flags.StringVar(&coreFile, "core-file", coreFile, "local Xray-core zip")
	flags.StringVar(&proxy, "proxy", proxy, "download proxy")
	flags.BoolVar(&skipCore, "skip-core", skipCore, "skip Xray-core download")
	if err := flags.Parse(args); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUsage
	}
	if tlsMode == "nginx" || tlsMode == "" {
		if err := configureACME(opts, acmeEmail, acmeNoEmail); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitConfig
		}
	}
	if opts.dryRun {
		if tlsMode == "nginx" || tlsMode == "" {
			if opts.root == "/" {
				installer := systemexec.PackageInstaller{Runner: opts.runner, Root: opts.root}
				if err := installer.EnsureNginxDependencies(context.Background(), proxy); err != nil {
					fmt.Fprintln(stderr, err)
					return ExitUnexpected
				}
			} else {
				fmt.Fprintln(stdout, "dry_run = install missing nginx certbot openssl systemd iproute dependencies")
			}
		}
		for _, action := range []string{
			"write /etc/xray/config.json",
			"write /etc/systemd/system/xray.service",
			"write TLS frontend include",
			"write /etc/letsencrypt/renewal-hooks/deploy/xray-nginx-reload",
		} {
			fmt.Fprintf(stdout, "dry_run_file = %s\n", action)
		}
		return finishInstallServices(opts, tlsMode, stdout, stderr)
	}
	if (tlsMode == "nginx" || tlsMode == "") && opts.root == "/" {
		installer := systemexec.PackageInstaller{Runner: opts.runner, Root: opts.root}
		if err := installer.EnsureNginxDependencies(context.Background(), proxy); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
	}
	if err := ensureInstallLayout(opts); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	if !skipCore {
		if err := installCore(opts, coreVersion, coreFile, proxy); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
	}
	if err := writeMainConfig(opts); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	if err := writeService(opts); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	switch tlsMode {
	case "caddy":
		if err := writeCaddyImport(opts); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
	case "nginx", "":
		if err := writeNginxInclude(opts); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
		if err := atomicWrite(opts.abs(frontendnginx.DeployHookPath), []byte(frontendnginx.DeployHook), 0o755); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
	default:
		fmt.Fprintf(stderr, "unsupported TLS frontend mode: %s\n", tlsMode)
		return ExitUnsupported
	}
	if code := finishInstallServices(opts, tlsMode, stdout, stderr); code != ExitOK {
		return code
	}
	fmt.Fprintf(stdout, "installed = true\n")
	fmt.Fprintf(stdout, "tls = %s\n", tlsMode)
	if tlsMode == "nginx" || tlsMode == "" {
		fmt.Fprintln(stdout, "firewall = open TCP 80 and 443")
		fmt.Fprintln(stdout, "next = xray add vws example.com")
	}
	return ExitOK
}

func finishInstallServices(opts options, tlsMode string, stdout, stderr io.Writer) int {
	commands := []systemexec.Command{
		{Name: opts.abs(xrayBinPath), Args: []string{"run", "-test", "-config", opts.configPath, "-confdir", opts.confDir}, Step: "validate Xray configuration"},
	}
	if tlsMode == "nginx" || tlsMode == "" {
		commands = append(commands,
			frontendnginx.ValidateCommand(),
			systemexec.Command{Name: "ss", Args: []string{"-ltnp"}, Step: "check TCP 80 and 443 listeners"},
		)
	}
	commands = append(commands,
		systemexec.Command{Name: "systemctl", Args: []string{"daemon-reload"}, Step: "reload systemd units"},
		systemexec.Command{Name: "systemctl", Args: []string{"enable", "--now", "xray"}, Step: "enable Xray service"},
	)
	if tlsMode == "nginx" || tlsMode == "" {
		commands = append(commands, systemexec.Command{Name: "systemctl", Args: []string{"enable", "--now", "nginx"}, Step: "enable Nginx service"})
	}
	for _, command := range commands {
		result, err := opts.runner.Run(context.Background(), command)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
		if command.Name == "ss" {
			if conflict := frontendnginx.ConflictingListener(result.Stdout); conflict != "" {
				fmt.Fprintf(stderr, "TCP 80 or 443 is occupied by another service: %s\n", conflict)
				return ExitConfig
			}
		}
	}
	if tlsMode == "nginx" || tlsMode == "" {
		if err := ensureCertbotScheduler(opts, stdout); err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnexpected
		}
	}
	return ExitOK
}

func ensureCertbotScheduler(opts options, output io.Writer) error {
	result, err := opts.runner.Run(context.Background(), systemexec.Command{
		Name: "systemctl", Args: []string{"list-unit-files", "certbot.timer", "certbot-renew.timer", "--no-legend"}, Step: "detect Certbot timer",
	})
	if timer := frontendnginx.RenewalTimerFromUnitFiles(result.Stdout); err == nil && timer != "" {
		return runRunner(opts, systemexec.Command{Name: "systemctl", Args: []string{"enable", "--now", timer}, Step: "enable Certbot timer"})
	}
	if _, statErr := os.Stat(opts.abs("/etc/cron.d/certbot")); statErr == nil {
		return nil
	}
	fmt.Fprintln(output, "warning = Certbot automatic renewal timer or cron job was not found")
	return nil
}

func configureACME(opts options, flagEmail string, flagNoEmail bool) error {
	path := opts.abs(acme.ConfigPath)
	var persisted *acme.Config
	if data, err := os.ReadFile(path); err == nil {
		config, err := acme.Parse(data)
		if err != nil {
			return err
		}
		persisted = &config
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}

	envEmail := strings.TrimSpace(os.Getenv("XRAY_ACME_EMAIL"))
	if strings.TrimSpace(flagEmail) == "" && !flagNoEmail && envEmail == "" && persisted == nil {
		return nil
	}
	config, err := acme.Resolve(flagEmail, flagNoEmail, envEmail, persisted)
	if err != nil {
		return err
	}
	data, err := acme.Marshal(config)
	if err != nil {
		return err
	}
	if opts.dryRun {
		return nil
	}
	return atomicWrite(path, data, 0o600)
}

func profileFromAddArgs(command string, args []string) (protocol.Profile, error) {
	if command == "no-auto-tls" {
		if len(args) == 0 {
			return protocol.Profile{}, fmt.Errorf("protocol required")
		}
		command = args[0]
		args = args[1:]
	} else {
		if len(args) == 0 {
			return protocol.Profile{}, fmt.Errorf("protocol required")
		}
		command = args[0]
		args = args[1:]
	}

	alias := strings.ToLower(command)
	id := protocol.FixedUUID
	password := protocol.FixedPassword
	port := 0
	var err error
	nextPort := func(defaultPort int) int {
		if defaultPort != 0 {
			return defaultPort
		}
		p, e := freePort()
		if e != nil {
			return 10000
		}
		return p
	}
	parsePort := func(index int) int {
		if len(args) <= index || args[index] == "" {
			return 0
		}
		p, e := strconv.Atoi(args[index])
		if e == nil {
			return p
		}
		return 0
	}

	switch alias {
	case "vws", "vh2", "vgrpc", "ws", "h2", "grpc", "tws", "th2", "tgrpc":
		host := argOr(args, 0, protocol.FixedHost)
		credential := argOr(args, 1, id)
		path := argOr(args, 2, protocol.FixedPath)
		port = nextPort(0)
		proto := "vmess"
		nameProto := "VMess"
		if strings.HasPrefix(alias, "v") {
			proto = "vless"
			nameProto = "VLESS"
			id = credential
		} else if strings.HasPrefix(alias, "t") {
			proto = "trojan"
			nameProto = "Trojan"
			password = credential
		} else {
			id = credential
		}
		network := strings.TrimPrefix(strings.TrimPrefix(strings.TrimPrefix(alias, "v"), "t"), "")
		if alias == "ws" || alias == "h2" || alias == "grpc" {
			network = alias
		}
		if network == "h2" {
			network = "ws"
		}
		profile := protocol.Profile{
			Key:      strings.ToLower(fmt.Sprintf("%s-%s-tls-%s", nameProto, network, host)),
			Name:     fmt.Sprintf("%s-%s-TLS-%s", nameProto, displayNetwork(network), host),
			Protocol: proto,
			Port:     port,
			Listen:   "127.0.0.1",
			ID:       id,
			Password: password,
			Network:  network,
			Security: "tls",
			Host:     host,
			Path:     ensureSlash(path),
		}
		if network == "grpc" {
			profile.Path = ""
			profile.ServiceName = strings.TrimPrefix(path, "/")
			if profile.ServiceName == "" {
				profile.ServiceName = protocol.FixedGRPCService
			}
		}
		return profile, nil
	case "vxhttp", "txhttp":
		port = parsePort(0)
		credential := argOr(args, 1, id)
		host := argOr(args, 2, protocol.FixedHost)
		path := argOr(args, 3, protocol.FixedPath)
		if port == 0 {
			port = nextPort(0)
		}
		proto := "vless"
		name := "VLESS-XHTTP-TLS"
		if alias == "txhttp" {
			proto = "trojan"
			name = "Trojan-XHTTP-TLS"
			password = credential
		} else {
			id = credential
		}
		return protocol.Profile{
			Key:       strings.ToLower(name + "-" + host),
			Name:      name + "-" + host,
			Protocol:  proto,
			Port:      port,
			Listen:    "127.0.0.1",
			ID:        id,
			Password:  password,
			Network:   "xhttp",
			Security:  "tls",
			Host:      host,
			Path:      ensureSlash(path),
			XHTTPMode: "auto",
		}, nil
	case "r", "reality":
		port = parsePort(0)
		id = argOr(args, 1, id)
		sni := argOr(args, 2, protocol.FixedRealitySNI)
		if port == 0 {
			port = nextPort(0)
		}
		privateKey, publicKey, e := realityKeys()
		if e != nil {
			return protocol.Profile{}, e
		}
		return protocol.Profile{
			Key:         fmt.Sprintf("vless-reality-%d", port),
			Name:        fmt.Sprintf("VLESS-XTLS-uTLS-REALITY-%d", port),
			Protocol:    "vless",
			Port:        port,
			Listen:      "0.0.0.0",
			ID:          id,
			Network:     "tcp",
			Security:    "reality",
			Flow:        "xtls-rprx-vision",
			ServerName:  sni,
			Fingerprint: "ios",
			PrivateKey:  privateKey,
			PublicKey:   publicKey,
		}, nil
	case "tcp", "kcp", "quic":
		port = parsePort(0)
		id = argOr(args, 1, id)
		header := argOr(args, 2, "none")
		if port == 0 {
			port = nextPort(0)
		}
		return protocol.Profile{
			Key:        fmt.Sprintf("vmess-tcp-%d", port),
			Name:       fmt.Sprintf("VMess-TCP-%d", port),
			Protocol:   "vmess",
			Port:       port,
			Listen:     "0.0.0.0",
			ID:         id,
			Network:    "tcp",
			HeaderType: header,
		}, nil
	case "ss":
		port = parsePort(0)
		password = argOr(args, 1, password)
		method := argOr(args, 2, protocol.FixedSSMethod)
		if port == 0 {
			port = nextPort(0)
		}
		return protocol.Profile{
			Key:      fmt.Sprintf("shadowsocks-%d", port),
			Name:     fmt.Sprintf("Shadowsocks-%d", port),
			Protocol: "shadowsocks",
			Port:     port,
			Listen:   "0.0.0.0",
			Password: password,
			Method:   method,
			Network:  "tcp,udp",
		}, nil
	case "socks":
		port = parsePort(0)
		user := argOr(args, 1, protocol.FixedSocksUser)
		password = argOr(args, 2, password)
		if port == 0 {
			port = nextPort(0)
		}
		return protocol.Profile{
			Key:      fmt.Sprintf("socks-%d", port),
			Name:     fmt.Sprintf("Socks-%d", port),
			Protocol: "socks",
			Port:     port,
			Listen:   "0.0.0.0",
			ID:       user,
			Password: password,
			Network:  "tcp,udp",
		}, nil
	default:
		err = fmt.Errorf("unsupported add protocol: %s", alias)
	}
	return protocol.Profile{}, err
}

func writeProfile(opts options, profile protocol.Profile) error {
	fileName := profile.Name + ".json"
	if _, err := os.Stat(filepath.Join(opts.confDir, fileName)); err == nil {
		return fmt.Errorf("%w: %s", errConfigExists, fileName)
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return writeProfileAs(opts, profile, fileName)
}

func writeProfileAs(opts options, profile protocol.Profile, fileName string) error {
	out, err := protocol.XrayJSON(profile)
	if err != nil {
		return err
	}
	if err := ensureDir(opts.confDir); err != nil {
		return err
	}
	if err := atomicWrite(filepath.Join(opts.confDir, fileName), append(out, '\n'), 0o644); err != nil {
		return err
	}
	if err := writeMainConfig(opts); err != nil {
		return err
	}
	if profile.Host != "" {
		return writeFrontend(opts, profile)
	}
	return nil
}

func writeMainConfig(opts options) error {
	if err := ensureDir(filepath.Dir(opts.configPath)); err != nil {
		return err
	}
	out, err := renderMainConfig()
	if err != nil {
		return err
	}
	return atomicWrite(opts.configPath, out, 0o644)
}

func renderMainConfig() ([]byte, error) {
	doc := map[string]any{
		"log": map[string]any{
			"access":   "/var/log/xray/access.log",
			"error":    "/var/log/xray/error.log",
			"loglevel": "warning",
		},
		"inbounds": []map[string]any{{
			"tag":      "api",
			"port":     10085,
			"listen":   "127.0.0.1",
			"protocol": "dokodemo-door",
			"settings": map[string]any{"address": "127.0.0.1"},
		}},
		"outbounds": []map[string]any{
			{"tag": "direct", "protocol": "freedom"},
			{"tag": "block", "protocol": "blackhole"},
		},
		"routing": map[string]any{
			"domainStrategy": "IPIfNonMatch",
			"rules": []map[string]any{
				{"type": "field", "inboundTag": []string{"api"}, "outboundTag": "api"},
				{"type": "field", "ip": []string{"geoip:private"}, "outboundTag": "block"},
			},
		},
		"api":    map[string]any{"tag": "api", "services": []string{"HandlerService", "LoggerService", "StatsService"}},
		"stats":  map[string]any{},
		"policy": map[string]any{"system": map[string]any{"statsInboundUplink": true, "statsInboundDownlink": true}},
	}
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(out, '\n'), nil
}

func validateXrayCandidate(opts options, fileName string, candidate []byte, profile protocol.Profile) error {
	secrets := profileSecrets(profile)
	if opts.dryRun {
		return runRunner(opts, systemexec.Command{
			Name:            opts.abs(xrayBinPath),
			Args:            []string{"run", "-test", "-config", "/tmp/xray-add-candidate/config.json", "-confdir", "/tmp/xray-add-candidate/conf"},
			Step:            "validate staged Xray configuration",
			SensitiveValues: secrets,
		})
	}
	tmpRoot := opts.abs("/tmp")
	if err := os.MkdirAll(tmpRoot, 0o755); err != nil {
		return err
	}
	tmpDir, err := os.MkdirTemp(tmpRoot, "xray-add-candidate-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmpDir)
	confDir := filepath.Join(tmpDir, "conf")
	if err := os.MkdirAll(confDir, 0o755); err != nil {
		return err
	}
	files, err := filepath.Glob(filepath.Join(opts.confDir, "*.json"))
	if err != nil {
		return err
	}
	for _, source := range files {
		data, err := os.ReadFile(source)
		if err != nil {
			return err
		}
		if err := os.WriteFile(filepath.Join(confDir, filepath.Base(source)), data, 0o600); err != nil {
			return err
		}
	}
	if err := os.WriteFile(filepath.Join(confDir, fileName), candidate, 0o600); err != nil {
		return err
	}
	mainConfig, err := renderMainConfig()
	if err != nil {
		return err
	}
	configPath := filepath.Join(tmpDir, "config.json")
	if err := os.WriteFile(configPath, mainConfig, 0o644); err != nil {
		return err
	}
	return runRunner(opts, systemexec.Command{
		Name:            opts.abs(xrayBinPath),
		Args:            []string{"run", "-test", "-config", configPath, "-confdir", confDir},
		Step:            "validate staged Xray configuration",
		SensitiveValues: secrets,
	})
}

func checkFrontendConflict(opts options, profile protocol.Profile) error {
	if opts.tlsMode == "caddy" {
		site := opts.abs(filepath.Join(frontendcaddy.SiteDir, profile.Host+".conf"))
		mainConf, _, err := readOptionalApp(site)
		if err != nil {
			return err
		}
		addConf, _, err := readOptionalApp(site + ".add")
		if err != nil {
			return err
		}
		if len(mainConf) == 0 {
			return nil
		}
		check, err := frontendcaddy.CheckAppend(string(mainConf), string(addConf), profile)
		if err != nil {
			return err
		}
		if check.Status == frontendcaddy.AppendConflict {
			return fmt.Errorf("Caddy route %s already maps to port %d, requested port %d", check.Path, check.ExistingPort, check.WantedPort)
		}
		return nil
	}
	site := opts.abs(filepath.Join(frontendnginx.SiteDir, profile.Host+".conf"))
	mainConf, _, err := readOptionalApp(site)
	if err != nil {
		return err
	}
	addConf, _, err := readOptionalApp(site + ".add")
	if err != nil {
		return err
	}
	if len(mainConf) == 0 {
		return nil
	}
	check, err := frontendnginx.CheckAppend(string(mainConf), string(addConf), profile)
	if err != nil {
		return err
	}
	if check.Status == frontendnginx.AppendConflict {
		return fmt.Errorf("Nginx route %s already maps to port %d, requested port %d", check.Path, check.ExistingPort, check.WantedPort)
	}
	return nil
}

func loadACMEConfig(opts options) (acme.Config, error) {
	data, err := os.ReadFile(opts.abs(acme.ConfigPath))
	if errors.Is(err, os.ErrNotExist) {
		envEmail := strings.TrimSpace(os.Getenv("XRAY_ACME_EMAIL"))
		if envEmail == "" {
			return acme.Config{}, nil
		}
		return acme.Resolve("", false, envEmail, nil)
	}
	if err != nil {
		return acme.Config{}, err
	}
	return acme.Parse(data)
}

func profileSecrets(profile protocol.Profile) []string {
	return []string{profile.ID, profile.Password, profile.PrivateKey}
}

func runRunner(opts options, command systemexec.Command) error {
	_, err := opts.runner.Run(context.Background(), command)
	return err
}

type appFileSnapshot struct {
	path    string
	data    []byte
	mode    os.FileMode
	existed bool
}

func captureFile(path string) (appFileSnapshot, error) {
	snapshot := appFileSnapshot{path: path}
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return snapshot, nil
	}
	if err != nil {
		return snapshot, err
	}
	info, err := os.Stat(path)
	if err != nil {
		return snapshot, err
	}
	snapshot.data = data
	snapshot.mode = info.Mode().Perm()
	snapshot.existed = true
	return snapshot, nil
}

func restoreFiles(snapshots ...appFileSnapshot) error {
	var restoreErr error
	for _, snapshot := range snapshots {
		if snapshot.existed {
			restoreErr = errors.Join(restoreErr, atomicWrite(snapshot.path, snapshot.data, snapshot.mode))
			continue
		}
		if err := os.Remove(snapshot.path); err != nil && !errors.Is(err, os.ErrNotExist) {
			restoreErr = errors.Join(restoreErr, err)
		}
	}
	return restoreErr
}

func readOptionalApp(path string) ([]byte, bool, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil, false, nil
	}
	return data, err == nil, err
}

func writeService(opts options) error {
	path := opts.abs(xrayServicePath)
	if err := ensureDir(filepath.Dir(path)); err != nil {
		return err
	}
	content := fmt.Sprintf(`[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
User=root
ExecStart=%s run -config %s -confdir %s
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
`, opts.abs(xrayBinPath), opts.configPath, opts.confDir)
	return atomicWrite(path, []byte(content), 0o644)
}

func ensureInstallLayout(opts options) error {
	for _, dir := range []string{
		opts.abs("/etc/xray/bin"),
		opts.abs("/etc/xray/conf"),
		opts.abs("/etc/xray/sub"),
		opts.abs("/var/log/xray"),
		opts.abs(frontendnginx.SiteDir),
		opts.abs(frontendnginx.CertbotRoot),
		opts.abs(frontendcaddy.SiteDir),
	} {
		if err := ensureDir(dir); err != nil {
			return err
		}
	}
	return nil
}

func writeFrontend(opts options, profile protocol.Profile) error {
	switch opts.tlsMode {
	case "caddy":
		return writeCaddyFrontend(opts, profile)
	default:
		return writeNginxFrontend(opts, profile)
	}
}

func writeNginxFrontend(opts options, profile protocol.Profile) error {
	site := opts.abs(filepath.Join(frontendnginx.SiteDir, profile.Host+".conf"))
	add := site + ".add"
	if err := ensureDir(filepath.Dir(site)); err != nil {
		return err
	}
	if _, err := os.Stat(site); errors.Is(err, os.ErrNotExist) {
		out, err := frontendnginx.RenderSite(profile)
		if err != nil {
			return err
		}
		if err := atomicWrite(site, []byte(out), 0o644); err != nil {
			return err
		}
		return atomicWrite(add, nil, 0o644)
	}
	out, err := frontendnginx.RenderAdd(profile)
	if err != nil {
		return err
	}
	return appendOnce(add, out)
}

func writeCaddyFrontend(opts options, profile protocol.Profile) error {
	site := opts.abs(filepath.Join(frontendcaddy.SiteDir, profile.Host+".conf"))
	add := site + ".add"
	if err := ensureDir(filepath.Dir(site)); err != nil {
		return err
	}
	if _, err := os.Stat(site); errors.Is(err, os.ErrNotExist) {
		out, err := frontendcaddy.RenderSite(profile)
		if err != nil {
			return err
		}
		if err := atomicWrite(site, []byte(out), 0o644); err != nil {
			return err
		}
		return atomicWrite(add, nil, 0o644)
	}
	out, err := frontendcaddy.RenderAdd(profile)
	if err != nil {
		return err
	}
	return appendOnce(add, out)
}

func writeNginxInclude(opts options) error {
	if err := ensureDir(opts.abs(frontendnginx.SiteDir)); err != nil {
		return err
	}
	if err := repairNginxSites(opts); err != nil {
		return err
	}
	if err := repairCertbotRenewals(opts); err != nil {
		return err
	}
	path := opts.abs(nginxIncludePath)
	if err := ensureDir(filepath.Dir(path)); err != nil {
		return err
	}
	content := fmt.Sprintf("include %s/*.conf;\n", opts.abs(frontendnginx.SiteDir))
	if err := atomicWrite(path, []byte(content), 0o644); err != nil {
		return err
	}
	mainPath := opts.abs("/etc/nginx/nginx.conf")
	mainData, err := os.ReadFile(mainPath)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	updated, changed, err := frontendnginx.EnsureHTTPInclude(string(mainData), opts.abs(nginxIncludePath))
	if err != nil {
		return err
	}
	if !changed {
		return nil
	}
	return atomicWrite(mainPath, []byte(updated), 0o644)
}

func fixNginx(opts options, stdout, stderr io.Writer) error {
	if opts.dryRun {
		for _, action := range []string{"repair Nginx include", "repair managed Certbot redirects", "repair Certbot renewal", "migrate verified certificate paths", "write persistent deploy hook"} {
			fmt.Fprintf(stdout, "dry_run_file = %s\n", action)
		}
		if err := runRunner(opts, frontendnginx.ValidateCommand()); err != nil {
			return err
		}
		return runRunner(opts, frontendnginx.ReloadCommand())
	}
	paths := []string{
		opts.abs(nginxIncludePath),
		opts.abs("/etc/nginx/nginx.conf"),
		opts.abs(frontendnginx.DeployHookPath),
	}
	sites, err := filepath.Glob(filepath.Join(opts.abs(frontendnginx.SiteDir), "*.conf"))
	if err != nil {
		return err
	}
	paths = append(paths, sites...)
	for _, site := range sites {
		domain := strings.TrimSuffix(filepath.Base(site), ".conf")
		paths = append(paths, opts.abs(filepath.Join("/etc/letsencrypt/renewal", domain+".conf")))
		data, readErr := os.ReadFile(site)
		if readErr == nil && strings.Contains(string(data), "/etc/nginx/ssl/") && !certificateFilesPresent(opts, domain) {
			fmt.Fprintf(stderr, "warning: %s retains its old certificate path because a valid Let's Encrypt certificate was not confirmed\n", domain)
		}
	}
	snapshots := make([]appFileSnapshot, 0, len(paths))
	for _, path := range paths {
		snapshot, err := captureFile(path)
		if err != nil {
			return err
		}
		snapshots = append(snapshots, snapshot)
	}
	rollback := func(cause error) error {
		rollbackErr := restoreFiles(snapshots...)
		if rollbackErr == nil {
			if err := runRunner(opts, frontendnginx.ValidateCommand()); err == nil {
				rollbackErr = runRunner(opts, frontendnginx.ReloadCommand())
			} else {
				rollbackErr = err
			}
		}
		if rollbackErr != nil {
			return fmt.Errorf("%w; Nginx rollback failed: %v", cause, rollbackErr)
		}
		return cause
	}
	if err := writeNginxInclude(opts); err != nil {
		return rollback(err)
	}
	if err := atomicWrite(opts.abs(frontendnginx.DeployHookPath), []byte(frontendnginx.DeployHook), 0o755); err != nil {
		return rollback(err)
	}
	if err := runRunner(opts, frontendnginx.ValidateCommand()); err != nil {
		return rollback(err)
	}
	if err := runRunner(opts, frontendnginx.ReloadCommand()); err != nil {
		return rollback(err)
	}
	return nil
}

func certificateFilesPresent(opts options, domain string) bool {
	for _, path := range []string{frontendnginx.CertificatePath(domain), frontendnginx.PrivateKeyPath(domain)} {
		info, err := os.Stat(opts.abs(path))
		if err != nil || info.Size() == 0 {
			return false
		}
	}
	return true
}

func verifyCertificateWithRunner(opts options, domain string) error {
	certificate := opts.abs(frontendnginx.CertificatePath(domain))
	privateKey := opts.abs(frontendnginx.PrivateKeyPath(domain))
	commands := []systemexec.Command{
		{Name: "openssl", Args: []string{"x509", "-in", certificate, "-noout"}, Step: "parse TLS certificate"},
		{Name: "openssl", Args: []string{"pkey", "-in", privateKey, "-noout"}, Step: "parse TLS private key"},
		{Name: "openssl", Args: []string{"x509", "-in", certificate, "-noout", "-checkend", "0"}, Step: "check TLS certificate expiry"},
		{Name: "openssl", Args: []string{"x509", "-in", certificate, "-noout", "-checkhost", domain}, Step: "check TLS certificate domain"},
	}
	for _, command := range commands {
		if err := runRunner(opts, command); err != nil {
			return err
		}
	}
	return nil
}

func repairNginxSites(opts options) error {
	files, err := filepath.Glob(filepath.Join(opts.abs(frontendnginx.SiteDir), "*.conf"))
	if err != nil {
		return err
	}
	for _, path := range files {
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		domain := strings.TrimSuffix(filepath.Base(path), ".conf")
		repaired, _ := frontendnginx.RemoveManagedCertbotRedirects(string(data), domain)
		verified := certificateFilesPresent(opts, domain)
		if verified {
			verified = verifyCertificateWithRunner(opts, domain) == nil
		}
		repaired, _, warning := frontendnginx.MigrateCertificatePaths(repaired, domain, verified)
		if warning != "" {
			// The fix command reports this as a warning through unchanged content.
			_ = warning
		}
		if repaired == string(data) {
			continue
		}
		if err := atomicWrite(path, []byte(repaired), 0o644); err != nil {
			return err
		}
	}
	return nil
}

func repairCertbotRenewals(opts options) error {
	sites, err := filepath.Glob(filepath.Join(opts.abs(frontendnginx.SiteDir), "*.conf"))
	if err != nil {
		return err
	}
	for _, site := range sites {
		domain := strings.TrimSuffix(filepath.Base(site), ".conf")
		path := opts.abs(filepath.Join("/etc/letsencrypt/renewal", domain+".conf"))
		data, err := os.ReadFile(path)
		if errors.Is(err, os.ErrNotExist) {
			continue
		}
		if err != nil {
			return err
		}
		repaired, changed := frontendnginx.EnsureWebrootRenewal(string(data), domain)
		repaired, installerChanged := frontendnginx.RemoveNginxInstaller(repaired)
		changed = changed || installerChanged
		if !changed {
			continue
		}
		if err := atomicWrite(path, []byte(repaired), 0o600); err != nil {
			return err
		}
	}
	return nil
}

func writeCaddyImport(opts options) error {
	if err := ensureDir(opts.abs(frontendcaddy.SiteDir)); err != nil {
		return err
	}
	path := opts.abs(frontendcaddy.DefaultCaddyfile)
	if err := ensureDir(filepath.Dir(path)); err != nil {
		return err
	}
	content := fmt.Sprintf("import %s/*.conf\n", opts.abs(frontendcaddy.SiteDir))
	return atomicWrite(path, []byte(content), 0o644)
}

func removeFrontendRoute(opts options, profile protocol.Profile) {
	if profile.Host == "" {
		return
	}
	for _, renderer := range []struct {
		site string
		add  string
		text func(protocol.Profile) (string, error)
	}{
		{
			site: opts.abs(filepath.Join(frontendnginx.SiteDir, profile.Host+".conf")),
			add:  opts.abs(filepath.Join(frontendnginx.SiteDir, profile.Host+".conf.add")),
			text: frontendnginx.RenderAdd,
		},
		{
			site: opts.abs(filepath.Join(frontendcaddy.SiteDir, profile.Host+".conf")),
			add:  opts.abs(filepath.Join(frontendcaddy.SiteDir, profile.Host+".conf.add")),
			text: frontendcaddy.RenderAdd,
		},
	} {
		text, err := renderer.text(profile)
		if err != nil {
			continue
		}
		removeText(renderer.site, text)
		removeText(renderer.add, text)
	}
}

func writeSubscriptionFrontend(opts options, domain, token string) {
	route := fmt.Sprintf(`    location = /sub/%s/mihomo.yaml {
        default_type text/yaml;
        alias %s;
    }
`, token, opts.abs(subscriptionPath))
	_ = appendOnce(opts.abs(filepath.Join(frontendnginx.SiteDir, domain+".conf.add")), route)
}

func profilesFromStore(opts options, server string) ([]protocol.Profile, error) {
	nodes, err := config.ListNodes(opts.confDir)
	if err != nil {
		return nil, err
	}
	profiles := make([]protocol.Profile, 0, len(nodes))
	for _, node := range nodes {
		node = withServerAddress(node, server)
		profiles = append(profiles, protocol.ProfileFromNode(node))
	}
	sort.Slice(profiles, func(i, j int) bool { return strings.ToLower(profiles[i].Name) < strings.ToLower(profiles[j].Name) })
	return profiles, nil
}

func withServerAddress(node config.Node, server string) config.Node {
	server = strings.TrimSpace(server)
	if server != "" && node.Host == "" {
		node.AddressOverride = server
	}
	return node
}

func fullClientJSON(out []byte) ([]byte, error) {
	var doc map[string]any
	if err := json.Unmarshal(out, &doc); err != nil {
		return nil, err
	}
	inbound := map[string]any{
		"tag":      "socks-in",
		"port":     2333,
		"listen":   "127.0.0.1",
		"protocol": "socks",
		"settings": map[string]any{"udp": true},
	}
	doc["inbounds"] = []map[string]any{inbound}
	doc["routing"] = map[string]any{"rules": []any{}}
	return json.MarshalIndent(doc, "", "  ")
}

func ensureToken(opts options) (string, error) {
	path := opts.abs(tokenPath)
	if data, err := os.ReadFile(path); err == nil && strings.TrimSpace(string(data)) != "" {
		return strings.TrimSpace(string(data)), nil
	}
	token, err := randomHex(16)
	if err != nil {
		return "", err
	}
	if err := ensureDir(filepath.Dir(path)); err != nil {
		return "", err
	}
	if err := atomicWrite(path, []byte(token+"\n"), 0o600); err != nil {
		return "", err
	}
	return token, nil
}

func installCore(opts options, version, coreFile, proxy string) error {
	if coreFile == "" && opts.root != "/" {
		return atomicWrite(opts.abs(xrayBinPath), []byte("#!/bin/sh\nexit 0\n"), 0o755)
	}
	zipPath := coreFile
	if zipPath == "" {
		tmp, err := os.CreateTemp("", "xray-core-*.zip")
		if err != nil {
			return err
		}
		zipPath = tmp.Name()
		tmp.Close()
		defer os.Remove(zipPath)
		if err := downloadCoreZip(zipPath, version, proxy); err != nil {
			return err
		}
	}
	return unzipCore(zipPath, opts.abs("/etc/xray/bin"))
}

func downloadCoreZip(path, version, proxy string) error {
	arch, err := download.NormalizeArch(runtime.GOARCH)
	if err != nil {
		return err
	}
	asset := "Xray-linux-64.zip"
	if arch.Go == "arm64" {
		asset = "Xray-linux-arm64-v8a.zip"
	}
	base := "https://github.com/XTLS/Xray-core/releases/latest/download/" + asset
	if version != "" && version != "latest" {
		base = fmt.Sprintf("https://github.com/XTLS/Xray-core/releases/download/%s/%s", version, asset)
	}
	client := &http.Client{Timeout: 60 * time.Second}
	if proxy != "" {
		proxyURL, err := url.Parse(proxy)
		if err != nil {
			return err
		}
		client.Transport = &http.Transport{Proxy: http.ProxyURL(proxyURL)}
	}
	resp, err := client.Get(base)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("download %s: %s", base, resp.Status)
	}
	out, err := os.Create(path)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, resp.Body)
	return err
}

func unzipCore(zipPath, targetDir string) error {
	if err := ensureDir(targetDir); err != nil {
		return err
	}
	zr, err := zip.OpenReader(zipPath)
	if err != nil {
		return err
	}
	defer zr.Close()
	allowed := map[string]bool{"xray": true, "geoip.dat": true, "geosite.dat": true}
	for _, file := range zr.File {
		name := filepath.Base(file.Name)
		if !allowed[name] {
			continue
		}
		rc, err := file.Open()
		if err != nil {
			return err
		}
		data, err := io.ReadAll(rc)
		rc.Close()
		if err != nil {
			return err
		}
		mode := os.FileMode(0o644)
		if name == "xray" {
			mode = 0o755
		}
		if err := atomicWrite(filepath.Join(targetDir, name), data, mode); err != nil {
			return err
		}
	}
	return nil
}

func runExternal(opts options, stdout, stderr io.Writer, name string, args ...string) int {
	if opts.root != "/" || opts.dryRun {
		fmt.Fprintf(stdout, "dry_run = %s %s\n", name, strings.Join(args, " "))
		return ExitOK
	}
	return runCommand(opts, nil, stdout, stderr, name, args...)
}

func runCommand(opts options, stdin io.Reader, stdout, stderr io.Writer, name string, args ...string) int {
	runner := opts.runner
	if runner == nil {
		runner = &systemexec.RealRunner{Stdin: stdin, Stdout: stdout, Stderr: stderr}
	}
	result, err := runner.Run(context.Background(), systemexec.Command{Name: name, Args: args})
	if err != nil {
		if result.ExitCode >= 0 {
			return result.ExitCode
		}
		fmt.Fprintln(stderr, err)
		return ExitUnexpected
	}
	return ExitOK
}

func freePort() (int, error) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	defer ln.Close()
	return ln.Addr().(*net.TCPAddr).Port, nil
}

func realityKeys() (string, string, error) {
	curve := ecdh.X25519()
	priv, err := curve.GenerateKey(rand.Reader)
	if err != nil {
		return "", "", err
	}
	enc := base64.RawURLEncoding
	return enc.EncodeToString(priv.Bytes()), enc.EncodeToString(priv.PublicKey().Bytes()), nil
}

func randomHex(bytesLen int) (string, error) {
	buf := make([]byte, bytesLen)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	sum := sha256.Sum256(buf)
	return hex.EncodeToString(sum[:bytesLen]), nil
}

func atomicWrite(path string, data []byte, mode os.FileMode) error {
	if err := ensureDir(filepath.Dir(path)); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, mode); err != nil {
		return err
	}
	if err := os.Chmod(tmp, mode); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func appendOnce(path, text string) error {
	if err := ensureDir(filepath.Dir(path)); err != nil {
		return err
	}
	data, _ := os.ReadFile(path)
	if strings.Contains(string(data), strings.TrimSpace(text)) {
		return nil
	}
	var buf bytes.Buffer
	buf.Write(data)
	if len(data) > 0 && !strings.HasSuffix(string(data), "\n") {
		buf.WriteByte('\n')
	}
	buf.WriteString(text)
	if !strings.HasSuffix(text, "\n") {
		buf.WriteByte('\n')
	}
	return atomicWrite(path, buf.Bytes(), 0o644)
}

func removeText(path, text string) {
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	out := strings.ReplaceAll(string(data), text, "")
	_ = atomicWrite(path, []byte(out), 0o644)
}

func ensureDir(path string) error {
	return os.MkdirAll(path, 0o755)
}

func firstArg(args []string) string {
	if len(args) == 0 {
		return ""
	}
	return args[0]
}

func argOr(args []string, index int, fallback string) string {
	if len(args) <= index || args[index] == "" {
		return fallback
	}
	return args[index]
}

func ensureSlash(value string) string {
	if value == "" {
		return "/"
	}
	if strings.HasPrefix(value, "/") {
		return value
	}
	return "/" + value
}

func displayNetwork(network string) string {
	if network == "grpc" {
		return "gRPC"
	}
	return strings.ToUpper(network)
}

func replaceTrailingPort(name string, port int) string {
	parts := strings.Split(name, "-")
	if len(parts) == 0 {
		return name
	}
	if _, err := strconv.Atoi(parts[len(parts)-1]); err == nil {
		parts[len(parts)-1] = strconv.Itoa(port)
		return strings.Join(parts, "-")
	}
	return fmt.Sprintf("%s-%d", name, port)
}
