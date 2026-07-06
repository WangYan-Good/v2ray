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
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/WangYan-Good/xray/internal/config"
	"github.com/WangYan-Good/xray/internal/download"
	frontendcaddy "github.com/WangYan-Good/xray/internal/frontend/caddy"
	frontendnginx "github.com/WangYan-Good/xray/internal/frontend/nginx"
	"github.com/WangYan-Good/xray/internal/protocol"
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
	if err := writeProfile(opts, profile); err != nil {
		fmt.Fprintln(stderr, err)
		if errors.Is(err, errConfigExists) {
			return ExitConfig
		}
		return ExitUnexpected
	}
	fmt.Fprintf(stdout, "added = %s\n", profile.Name)
	fmt.Fprintf(stdout, "file = %s\n", filepath.Join(opts.confDir, profile.Name+".json"))
	if share, err := protocol.ShareURL(profile.Node()); err == nil {
		fmt.Fprintf(stdout, "url = %s\n", share)
	}
	return ExitOK
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
		if err := writeNginxInclude(opts); err != nil {
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

func runConfigTest(opts options, _ []string, stdout, stderr io.Writer) int {
	return runExternal(opts, stdout, stderr, opts.abs(xrayBinPath), "run", "-test", "-config", opts.configPath, "-confdir", opts.confDir)
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
	flags.StringVar(&tlsMode, "tls", tlsMode, "TLS frontend mode")
	flags.StringVar(&coreVersion, "core-version", coreVersion, "Xray-core version")
	flags.StringVar(&coreFile, "core-file", coreFile, "local Xray-core zip")
	flags.StringVar(&proxy, "proxy", proxy, "download proxy")
	flags.BoolVar(&skipCore, "skip-core", skipCore, "skip Xray-core download")
	if err := flags.Parse(args); err != nil {
		fmt.Fprintln(stderr, err)
		return ExitUsage
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
	default:
		fmt.Fprintf(stderr, "unsupported TLS frontend mode: %s\n", tlsMode)
		return ExitUnsupported
	}
	fmt.Fprintf(stdout, "installed = true\n")
	fmt.Fprintf(stdout, "tls = %s\n", tlsMode)
	return ExitOK
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
		return err
	}
	return atomicWrite(opts.configPath, append(out, '\n'), 0o644)
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
	return atomicWrite(path, []byte(content), 0o644)
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
		repaired := removeManagedCertbotRedirect(string(data))
		if repaired == string(data) {
			continue
		}
		if err := atomicWrite(path, []byte(repaired), 0o644); err != nil {
			return err
		}
	}
	return nil
}

func removeManagedCertbotRedirect(content string) string {
	lines := strings.Split(content, "\n")
	out := make([]string, 0, len(lines))
	skipping := false
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !skipping && strings.HasPrefix(trimmed, "if ($host = ") {
			skipping = true
			continue
		}
		if skipping {
			if strings.Contains(trimmed, "} # managed by Certbot") {
				skipping = false
			}
			continue
		}
		out = append(out, line)
	}
	return strings.TrimRight(strings.Join(out, "\n"), "\n") + "\n"
}

func repairCertbotRenewals(opts options) error {
	files, err := filepath.Glob(opts.abs("/etc/letsencrypt/renewal/*.conf"))
	if err != nil {
		return err
	}
	for _, path := range files {
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		domain := strings.TrimSuffix(filepath.Base(path), ".conf")
		repaired, changed := frontendnginx.EnsureWebrootRenewal(string(data), domain)
		withoutInstaller := removeNginxRenewalInstaller(repaired)
		if withoutInstaller != repaired {
			repaired = withoutInstaller
			changed = true
		}
		if !changed {
			continue
		}
		if err := atomicWrite(path, []byte(repaired), 0o644); err != nil {
			return err
		}
	}
	return nil
}

func removeNginxRenewalInstaller(content string) string {
	lines := strings.Split(content, "\n")
	out := make([]string, 0, len(lines))
	for _, line := range lines {
		if strings.TrimSpace(line) == "installer = nginx" {
			continue
		}
		out = append(out, line)
	}
	return strings.TrimRight(strings.Join(out, "\n"), "\n") + "\n"
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
	if opts.root != "/" || opts.dryRun {
		fmt.Fprintf(stdout, "dry_run = %s %s\n", name, strings.Join(args, " "))
		return ExitOK
	}
	cmd := exec.CommandContext(context.Background(), name, args...)
	cmd.Stdin = stdin
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	if err := cmd.Run(); err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			return exitErr.ExitCode()
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
