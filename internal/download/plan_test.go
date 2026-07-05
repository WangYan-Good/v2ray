package download

import (
	"strings"
	"testing"
)

func TestNormalizeArch(t *testing.T) {
	amd64, err := NormalizeArch("x86_64")
	if err != nil {
		t.Fatal(err)
	}
	if amd64.Go != "amd64" || amd64.Xray != "64" || amd64.Caddy != "amd64" || amd64.JQ != "amd64" {
		t.Fatalf("amd64 arch = %+v", amd64)
	}

	arm64, err := NormalizeArch("aarch64")
	if err != nil {
		t.Fatal(err)
	}
	if arm64.Go != "arm64" || arm64.Xray != "arm64-v8a" {
		t.Fatalf("arm64 arch = %+v", arm64)
	}

	if _, err := NormalizeArch("riscv64"); err == nil {
		t.Fatal("expected unsupported architecture error")
	}
}

func TestCorePlanURLsAndProxy(t *testing.T) {
	plan, err := NewPlan(PlanOptions{
		Kind:    "core",
		Version: "v1.8.24",
		Machine: "x86_64",
		Proxy:   "http://127.0.0.1:7890",
	})
	if err != nil {
		t.Fatal(err)
	}
	out := FormatPlan(plan)
	for _, want := range []string{
		"kind = core",
		"asset.0.name = Xray-linux-64.zip",
		"asset.0.url = https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip",
		"asset.0.checksum_url = https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip.dgst",
		"proxy.http_proxy = http://127.0.0.1:7890",
		"proxy.HTTPS_PROXY = http://127.0.0.1:7890",
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("plan missing %q:\n%s", want, out)
		}
	}
}

func TestArmCoreAndCaddyPlans(t *testing.T) {
	core, err := NewPlan(PlanOptions{Kind: "core", Version: "v1.8.24", Machine: "aarch64"})
	if err != nil {
		t.Fatal(err)
	}
	if got := core.Assets[0].Name; got != "Xray-linux-arm64-v8a.zip" {
		t.Fatalf("core asset = %s", got)
	}

	caddy, err := NewPlan(PlanOptions{Kind: "caddy", Version: "v2.8.4", Machine: "arm64"})
	if err != nil {
		t.Fatal(err)
	}
	if got := caddy.Assets[0].Name; got != "caddy_2.8.4_linux_arm64.tar.gz" {
		t.Fatalf("caddy asset = %s", got)
	}
	if !strings.Contains(caddy.Assets[0].ChecksumURL, "caddy_2.8.4_checksums.txt") {
		t.Fatalf("caddy checksum url = %s", caddy.Assets[0].ChecksumURL)
	}
}

func TestDatAndGoPlans(t *testing.T) {
	dat, err := NewPlan(PlanOptions{Kind: "dat", Machine: "x86_64"})
	if err != nil {
		t.Fatal(err)
	}
	if len(dat.Assets) != 2 || dat.Assets[0].Name != "geoip.dat" || dat.Assets[1].Name != "geosite.dat" {
		t.Fatalf("dat assets = %+v", dat.Assets)
	}

	goPlan, err := NewPlan(PlanOptions{Kind: "go", Version: "v2.0.0-alpha", Machine: "x86_64"})
	if err != nil {
		t.Fatal(err)
	}
	if got := goPlan.Assets[0].Name; got != "xray-linux-amd64.tar.gz" {
		t.Fatalf("go asset = %s", got)
	}
	if !strings.Contains(FormatPlan(goPlan), "install xray binary to /usr/local/bin/xray after Phase 5 switch") {
		t.Fatalf("go install steps missing phase 5 guard:\n%s", FormatPlan(goPlan))
	}
}

func TestChecksumParsing(t *testing.T) {
	data := []byte("xray")
	hash := SHA256Hex(data)
	if err := VerifySHA256(data, hash); err != nil {
		t.Fatal(err)
	}
	if err := VerifySHA256(data, strings.Repeat("0", 64)); err == nil {
		t.Fatal("expected checksum mismatch")
	}

	xrayDigest := "SHA2-256= " + hash + "\n"
	parsed, err := ParseXrayDigest(xrayDigest)
	if err != nil {
		t.Fatal(err)
	}
	if parsed != hash {
		t.Fatalf("xray digest = %s", parsed)
	}

	checksumText := hash + "  caddy_2.8.4_linux_amd64.tar.gz\n"
	parsed, err = ParseChecksum(checksumText, "caddy_2.8.4_linux_amd64.tar.gz")
	if err != nil {
		t.Fatal(err)
	}
	if parsed != hash {
		t.Fatalf("checksum = %s", parsed)
	}
}

func TestSelectAssetDigest(t *testing.T) {
	release := `{"assets":[{"name":"code.zip","digest":"sha256:` + strings.Repeat("a", 64) + `"},{"name":"install.sh","digest":"sha256:` + strings.Repeat("b", 64) + `"}]}`
	digest, err := SelectAssetDigest(release, "code.zip")
	if err != nil {
		t.Fatal(err)
	}
	if digest != strings.Repeat("a", 64) {
		t.Fatalf("digest = %s", digest)
	}
	if _, err := SelectAssetDigest(release, "missing.zip"); err == nil {
		t.Fatal("expected missing asset error")
	}
}
