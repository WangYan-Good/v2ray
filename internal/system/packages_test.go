package system

import (
	"context"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestNginxPackagePlanDebian(t *testing.T) {
	distro := ParseOSRelease("ID=ubuntu\nID_LIKE=debian\nVERSION_ID=24.04\n")
	plan, err := NginxPackagePlan(distro, "apt-get", "http://127.0.0.1:7890", []string{"nginx", "certbot", "openssl", "systemctl", "ss"})
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"nginx", "certbot", "openssl", "systemd", "iproute2"}
	if !reflect.DeepEqual(plan.PackageList, want) {
		t.Fatalf("packages = %v", plan.PackageList)
	}
	if plan.Update == nil || plan.Install.Env["HTTPS_PROXY"] == "" || plan.EnableEPEL != nil {
		t.Fatalf("plan = %+v", plan)
	}
}

func TestPackageInstallerUsesRunner(t *testing.T) {
	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, "etc"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "etc/os-release"), []byte("ID=ubuntu\nID_LIKE=debian\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	runner := &RecordingRunner{}
	installer := PackageInstaller{
		Runner: runner,
		Root:   root,
		LookPath: func(name string) bool {
			return name == "apt-get"
		},
	}
	if err := installer.EnsureNginxDependencies(context.Background(), ""); err != nil {
		t.Fatal(err)
	}
	commands := runner.Strings()
	if len(commands) != 7 {
		t.Fatalf("commands = %v", commands)
	}
	if commands[0] != "apt-get update" || commands[1] != "apt-get install -y nginx certbot openssl systemd iproute2" {
		t.Fatalf("commands = %v", commands)
	}
}

func TestNginxPackagePlanRockyUsesEPEL(t *testing.T) {
	distro := ParseOSRelease("ID=rocky\nID_LIKE=\"rhel centos fedora\"\n")
	plan, err := NginxPackagePlan(distro, "dnf", "", []string{"nginx", "certbot", "ss"})
	if err != nil {
		t.Fatal(err)
	}
	if plan.EnableEPEL == nil || plan.EnableEPEL.String() != "dnf install -y epel-release" {
		t.Fatalf("plan = %+v", plan)
	}
	want := []string{"nginx", "certbot", "iproute"}
	if !reflect.DeepEqual(plan.PackageList, want) {
		t.Fatalf("packages = %v", plan.PackageList)
	}
}

func TestNginxPackagePlanRHELUsesOfficialEPELRelease(t *testing.T) {
	distro := ParseOSRelease("ID=rhel\nID_LIKE=fedora\nVERSION_ID=9.5\n")
	plan, err := NginxPackagePlan(distro, "dnf", "", []string{"certbot"})
	if err != nil {
		t.Fatal(err)
	}
	want := "dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm"
	if plan.EnableEPEL == nil || plan.EnableEPEL.String() != want {
		t.Fatalf("EPEL command = %v", plan.EnableEPEL)
	}
}
