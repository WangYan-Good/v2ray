package app

import (
	"flag"
	"fmt"
	"io"

	"github.com/WangYan-Good/xray/internal/config"
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
	noColor    bool
}

func Run(args []string, stdout, stderr io.Writer) int {
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
		ui.Info(stdout, node)
		return ExitOK
	case "url":
		node, err := matchNode(opts.confDir, commandArgs)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitConfig
		}
		shareURL, err := protocol.ShareURL(node)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return ExitUnsupported
		}
		fmt.Fprintln(stdout, shareURL)
		return ExitOK
	case "gen":
		return runGen(commandArgs, stdout, stderr)
	default:
		fmt.Fprintf(stderr, "unknown command: %s\n", command)
		return ExitUsage
	}
}

func parseArgs(args []string, stderr io.Writer) (options, []string, error) {
	opts := options{
		confDir:    "/etc/xray/conf",
		configPath: "/etc/xray/config.json",
		noColor:    true,
	}
	flags := flag.NewFlagSet("xray", flag.ContinueOnError)
	flags.SetOutput(stderr)
	flags.StringVar(&opts.confDir, "conf-dir", opts.confDir, "managed Xray config directory")
	flags.StringVar(&opts.configPath, "config", opts.configPath, "main Xray config path")
	flags.BoolVar(&opts.noColor, "no-color", opts.noColor, "disable color output")
	if err := flags.Parse(args); err != nil {
		return opts, nil, err
	}
	return opts, flags.Args(), nil
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
	flags.StringVar(&format, "format", format, "generation format: xray, client, or mihomo")
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
	default:
		fmt.Fprintf(stderr, "unsupported gen format: %s\n", format)
		return ExitUsage
	}
}
