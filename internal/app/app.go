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
