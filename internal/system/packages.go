package system

import (
	"bufio"
	"fmt"
	"strconv"
	"strings"
)

type Distribution struct {
	ID        string
	IDLike    []string
	VersionID string
}

func ParseOSRelease(content string) Distribution {
	values := make(map[string]string)
	scanner := bufio.NewScanner(strings.NewReader(content))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		value := strings.TrimSpace(parts[1])
		if unquoted, err := strconv.Unquote(value); err == nil {
			value = unquoted
		}
		values[strings.TrimSpace(parts[0])] = value
	}
	return Distribution{
		ID:        strings.ToLower(values["ID"]),
		IDLike:    strings.Fields(strings.ToLower(values["ID_LIKE"])),
		VersionID: values["VERSION_ID"],
	}
}

type PackagePlan struct {
	Manager     string
	Update      *Command
	EnableEPEL  *Command
	Install     Command
	PackageList []string
}

func NginxPackagePlan(distribution Distribution, manager, proxy string, missingCommands []string) (PackagePlan, error) {
	if manager != "apt-get" && manager != "dnf" && manager != "yum" {
		return PackagePlan{}, fmt.Errorf("unsupported package manager: %s", manager)
	}
	packages := packageNames(manager, missingCommands)
	plan := PackagePlan{Manager: manager, PackageList: packages}
	if len(packages) == 0 {
		return plan, nil
	}
	env := ProxyEnvironment(proxy)
	if manager == "apt-get" {
		if distribution.ID != "debian" && distribution.ID != "ubuntu" && !contains(distribution.IDLike, "debian") {
			return PackagePlan{}, fmt.Errorf("apt-get is unsupported for distribution %q", distribution.ID)
		}
		update := Command{Name: manager, Args: []string{"update"}, Env: env, Step: "refresh apt package index"}
		plan.Update = &update
		plan.Install = Command{Name: manager, Args: append([]string{"install", "-y"}, packages...), Env: env, Step: "install Nginx dependencies"}
		return plan, nil
	}

	if !isRHELLike(distribution) {
		return PackagePlan{}, fmt.Errorf("%s is unsupported for distribution %q", manager, distribution.ID)
	}
	if contains(missingCommands, "certbot") {
		epelPackage := "epel-release"
		if distribution.ID == "rhel" {
			major := strings.SplitN(distribution.VersionID, ".", 2)[0]
			if major == "" {
				return PackagePlan{}, fmt.Errorf("RHEL VERSION_ID is required to enable EPEL")
			}
			epelPackage = fmt.Sprintf("https://dl.fedoraproject.org/pub/epel/epel-release-latest-%s.noarch.rpm", major)
		}
		epel := Command{Name: manager, Args: []string{"install", "-y", epelPackage}, Env: env, Step: "enable EPEL for Certbot"}
		plan.EnableEPEL = &epel
	}
	plan.Install = Command{Name: manager, Args: append([]string{"install", "-y"}, packages...), Env: env, Step: "install Nginx dependencies"}
	return plan, nil
}

func ProxyEnvironment(proxy string) map[string]string {
	proxy = strings.TrimSpace(proxy)
	if proxy == "" {
		return nil
	}
	return map[string]string{
		"http_proxy":  proxy,
		"https_proxy": proxy,
		"HTTP_PROXY":  proxy,
		"HTTPS_PROXY": proxy,
	}
}

func packageNames(manager string, commands []string) []string {
	seen := make(map[string]bool)
	var packages []string
	for _, command := range commands {
		name := command
		switch command {
		case "systemctl":
			name = "systemd"
		case "ss":
			if manager == "apt-get" {
				name = "iproute2"
			} else {
				name = "iproute"
			}
		}
		if name == "" || seen[name] {
			continue
		}
		seen[name] = true
		packages = append(packages, name)
	}
	return packages
}

func isRHELLike(distribution Distribution) bool {
	switch distribution.ID {
	case "almalinux", "rocky", "rhel", "centos", "ol":
		return true
	}
	return contains(distribution.IDLike, "rhel") || contains(distribution.IDLike, "fedora")
}

func contains(values []string, wanted string) bool {
	for _, value := range values {
		if value == wanted {
			return true
		}
	}
	return false
}
