package acme

import (
	"strings"
	"testing"
)

func TestResolvePrecedence(t *testing.T) {
	persisted := &Config{Email: "saved@example.com"}
	config, err := Resolve("flag@example.com", false, "env@example.com", persisted)
	if err != nil {
		t.Fatal(err)
	}
	if config.Email != "flag@example.com" {
		t.Fatalf("email = %q", config.Email)
	}

	config, err = Resolve("", false, "env@example.com", persisted)
	if err != nil || config.Email != "env@example.com" {
		t.Fatalf("config = %+v, error = %v", config, err)
	}
}

func TestResolveRequiresExplicitNoEmail(t *testing.T) {
	_, err := Resolve("", false, "", nil)
	if err == nil || !strings.Contains(err.Error(), "ACME email is required") {
		t.Fatalf("error = %v", err)
	}
	config, err := Resolve("", true, "", nil)
	if err != nil || !config.NoEmail {
		t.Fatalf("config = %+v, error = %v", config, err)
	}
}

func TestMarshalDoesNotMixEmailModes(t *testing.T) {
	_, err := Marshal(Config{Email: "user@example.com", NoEmail: true})
	if err == nil {
		t.Fatal("expected mutually exclusive mode error")
	}
}
