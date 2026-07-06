package app

import (
	"flag"
	"fmt"
	"io"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/WangYan-Good/xray/internal/config"
	"github.com/WangYan-Good/xray/internal/download"
	frontendcaddy "github.com/WangYan-Good/xray/internal/frontend/caddy"
	frontendnginx "github.com/WangYan-Good/xray/internal/frontend/nginx"
	"github.com/WangYan-Good/xray/internal/protocol"
	"github.com/WangYan-Good/xray/internal/ui"
)

const (
	ExitOK          = 0
	ExitUnexpected  = 1
	ExitUsage       = 2
	ExitConfig      = 3
	ExitUnsupported = 4
)

type options struct {
	confDir    string
	configPath string
	root       string
	tlsMode    string
	server     string
	noColor    bool
	dryRun     bool
}

func Run(args []string, stdout, stderr io.Writer) int {
	return RunWithIO(args, nil, stdout, stderr)
}

func RunWithIO(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	return runApp(args, stdin, stdout, stderr)
}

func runApp(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	opts, rest, err := parseArgs(args, stderr)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUsage
	}
	if len(rest) == 0 {
		fmt.Fprintln(stderr, "missing command")
		return ExitUsage
	}

	command := rest[0]
	commandArgs := rest[1:]

	switch command {
	case "version", "ver", "v":
		ui.Version(stdout, opts.confDir)
		return ExitOK
	case "status", "s":
		nodes, err := config.ListNodes(opts.confDir)
		if err != nil {
			fmt.Fprintf(stderr, "status warning: %v\n", err)
			nodes = nil
		}
		ui.Status(stdout, opts.confDir, opts.configPath, nodes)
		return ExitOK
	case "info", "i":
		node, err := matchNode(opts.confDir, commandArgs)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitConfig
		}
		node = withServerAddress(node, opts.server)
		ui.Info(stdout, node)
		return ExitOK
	case "url":
		node, err := matchNode(opts.confDir, commandArgs)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitConfig
		}
		node = withServerAddress(node, opts.server)
		shareURL, err := protocol.ShareURL(node)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnsupported
		}
		fmt.Fprintln(stdout, shareURL)
		return ExitOK
	case "gen":
		return runGen(commandArgs, stdout, stderr)
	case "download-plan":
		return runDownloadPlan(commandArgs, stdout, stderr)
	case "switch-plan":
		return runSwitchPlan(commandArgs, stdout, stderr)
	case "install":
		return runInstall(opts, commandArgs, stdout, stderr)
	case "add", "a", "no-auto-tls":
		return runAdd(opts, command, commandArgs, stdout, stderr)
	case "change", "config", "c":
		return runChange(opts, commandArgs, stdout, stderr)
	case "del", "rm", "d":
		return runDel(opts, commandArgs, stdout, stderr)
	case "ddel", "dd":
		return runDeleteMany(opts, commandArgs, stdout, stderr)
	case "fix", "fix-all", "fix-config.json", "fix-caddyfile", "fix-nginxfile":
		return runFix(opts, command, commandArgs, stdout, stderr)
	case "client", "genc":
		return runClient(opts, command == "client", commandArgs, stdout, stderr)
	case "mihomo", "clash":
		return runMihomo(opts, commandArgs, stdout, stderr)
	case "refresh-sub", "sub-refresh":
		return runRefreshSub(opts, commandArgs, stdout, stderr)
	case "sub-url":
		return runSubURL(opts, commandArgs, stdout, stderr)
	case "qr":
		return runQR(opts, commandArgs, stdout, stderr)
	case "start", "stop", "restart", "r":
		return runService(opts, command, commandArgs, stdout, stderr)
	case "test", "t":
		return runConfigTest(opts, commandArgs, stdout, stderr)
	case "update", "up", "u", "update.sh", "U", "reinstall":
		return runUpdate(opts, command, commandArgs, stdout, stderr)
	case "uninstall", "un":
		return runUninstall(opts, commandArgs, stdout, stderr)
	case "log", "logerr", "errlog":
		return runLog(opts, command, commandArgs, stdout, stderr)
	case "dns":
		return runDNS(opts, commandArgs, stdout, stderr)
	case "bbr":
		return runBBR(opts, commandArgs, stdout, stderr)
	case "ip":
		return runIP(stdout, stderr)
	case "debug":
		return runDebug(opts, commandArgs, stdout, stderr)
	case "get-port":
		return runGetPort(stdout, stderr)
	case "api", "xapi", "bin", "run", "uuid", "tls", "convert":
		return runCorePassthrough(opts, command, commandArgs, stdin, stdout, stderr)
	case "ssss", "ss2022":
		return runSS2022(stdout, stderr)
	case "help", "h", "--help", "main":
		return runHelp(commandArgs, stdout)
	default:
		fmt.Fprintf(stderr, "unknown command: %s\n", command)
		return ExitUsage
	}
}

func parseArgs(args []string, stderr io.Writer) (options, []string, error) {
	opts := options{
		confDir:    "/etc/xray/conf",
		configPath: "/etc/xray/config.json",
		root:       "/",
		tlsMode:    "nginx",
		noColor:    true,
	}
	flags := flag.NewFlagSet("xray", flag.ContinueOnError)
	flags.SetOutput(stderr)
	flags.StringVar(&opts.confDir, "conf-dir", opts.confDir, "managed Xray config directory")
	flags.StringVar(&opts.configPath, "config", opts.configPath, "main Xray config path")
	flags.StringVar(&opts.root, "root", opts.root, "root directory for system file operations")
	flags.StringVar(&opts.tlsMode, "tls", opts.tlsMode, "TLS frontend mode: nginx or caddy")
	flags.StringVar(&opts.server, "server", opts.server, "public server address for direct protocols")
	flags.BoolVar(&opts.noColor, "no-color", opts.noColor, "disable color output")
	flags.BoolVar(&opts.dryRun, "dry-run", opts.dryRun, "print actions without changing external services")
	if err := flags.Parse(args); err != nil {
		return opts, nil, err
	}
	opts.root = filepath.Clean(opts.root)
	if opts.root == "." || opts.root == "" {
		opts.root = "/"
	}
	if opts.root != "/" {
		if opts.confDir == "/etc/xray/conf" {
			opts.confDir = opts.abs("/etc/xray/conf")
		}
		if opts.configPath == "/etc/xray/config.json" {
			opts.configPath = opts.abs("/etc/xray/config.json")
		}
	}
	return opts, flags.Args(), nil
}

func (o options) abs(path string) string {
	if o.root == "/" || o.root == "" {
		return path
	}
	if !strings.HasPrefix(path, "/") {
		return path
	}
	return filepath.Join(o.root, strings.TrimPrefix(path, "/"))
}

func matchNode(confDir string, args []string) (config.Node, error) {
	name := ""
	if len(args) > 0 {
		name = args[0]
	}
	return config.MatchNode(confDir, name)
}

func runGen(args []string, stdout, stderr io.Writer) int {
	format := "xray"
	flags := flag.NewFlagSet("xray gen", flag.ContinueOnError)
	flags.SetOutput(stderr)
	flags.StringVar(&format, "format", format, "generation format: xray, client, mihomo, nginx, nginx-add, caddy, or caddy-add")
	if err := flags.Parse(args); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUsage
	}

	rest := flags.Args()
	if format == "mihomo" && len(rest) == 0 {
		out, err := protocol.MihomoDocument(protocol.DefaultProfiles())
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnsupported
		}
		fmt.Fprint(stdout, out)
		return ExitOK
	}
	if len(rest) != 1 {
		fmt.Fprintln(stderr, "profile name required")
		return ExitUsage
	}

	profile, err := protocol.ProfileByName(rest[0])
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitConfig
	}

	switch format {
	case "xray":
		out, err := protocol.XrayJSON(profile)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnsupported
		}
		fmt.Fprintln(stdout, string(out))
		return ExitOK
	case "client":
		out, err := protocol.ClientJSON(profile)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnsupported
		}
		fmt.Fprintln(stdout, string(out))
		return ExitOK
	case "mihomo":
		out, supported, reason, err := protocol.MihomoProxyYAML(profile)
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
	case "nginx":
		out, err := frontendnginx.RenderSite(profile)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnsupported
		}
		fmt.Fprint(stdout, out)
		return ExitOK
	case "nginx-add":
		out, err := frontendnginx.RenderAdd(profile)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnsupported
		}
		fmt.Fprint(stdout, out)
		return ExitOK
	case "caddy":
		out, err := frontendcaddy.RenderSite(profile)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnsupported
		}
		fmt.Fprint(stdout, out)
		return ExitOK
	case "caddy-add":
		out, err := frontendcaddy.RenderAdd(profile)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnsupported
		}
		fmt.Fprint(stdout, out)
		return ExitOK
	default:
		fmt.Fprintf(stderr, "unsupported gen format: %s\n", format)
		return ExitUsage
	}
}

func runDownloadPlan(args []string, stdout, stderr io.Writer) int {
	opts := download.PlanOptions{
		Machine: runtime.GOARCH,
	}
	flags := flag.NewFlagSet("xray download-plan", flag.ContinueOnError)
	flags.SetOutput(stderr)
	flags.StringVar(&opts.Version, "version", opts.Version, "release version or latest")
	flags.StringVar(&opts.Machine, "arch", opts.Machine, "machine architecture")
	flags.StringVar(&opts.Proxy, "proxy", opts.Proxy, "download proxy")
	if err := flags.Parse(args); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUsage
	}
	rest := flags.Args()
	if len(rest) != 1 {
		fmt.Fprintln(stderr, "download kind required")
		return ExitUsage
	}
	opts.Kind = rest[0]

	plan, err := download.NewPlan(opts)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return ExitConfig
	}
	fmt.Fprint(stdout, download.FormatPlan(plan))
	return ExitOK
}

func runSwitchPlan(args []string, stdout, stderr io.Writer) int {
	mode := "go"
	flags := flag.NewFlagSet("xray switch-plan", flag.ContinueOnError)
	flags.SetOutput(stderr)
	flags.StringVar(&mode, "mode", mode, "switch mode: go or restore")
	if err := flags.Parse(args); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUsage
	}
	if flags.NArg() != 0 {
		fmt.Fprintln(stderr, "switch-plan does not accept positional arguments")
		return ExitUsage
	}
	fmt.Fprintf(stdout, "mode = %s\n", mode)
	fmt.Fprintln(stdout, "entry = /usr/local/bin/xray")
	fmt.Fprintln(stdout, "runtime = go")
	fmt.Fprintln(stdout, "install = install.sh downloads xray-linux-{arch}.tar.gz and verifies checksums.txt")
	fmt.Fprintln(stdout, "restore = reinstall the previous Go release asset or restore /usr/local/bin/xray from backup")
	return ExitOK
}
