package acme

import (
	"encoding/json"
	"fmt"
	"net/mail"
	"strings"
)

const ConfigPath = "/etc/xray/acme.json"

type Config struct {
	Email   string `json:"email,omitempty"`
	NoEmail bool   `json:"no_email,omitempty"`
}

func (c Config) Validate() error {
	email := strings.TrimSpace(c.Email)
	if email != "" && c.NoEmail {
		return fmt.Errorf("ACME email and no-email mode are mutually exclusive")
	}
	if email == "" {
		if c.NoEmail {
			return nil
		}
		return fmt.Errorf("ACME email is required; use --acme-email, XRAY_ACME_EMAIL, or explicitly --acme-no-email")
	}
	address, err := mail.ParseAddress(email)
	if err != nil || address.Address != email || !strings.Contains(email, "@") {
		return fmt.Errorf("invalid ACME email address")
	}
	return nil
}

func Resolve(flagEmail string, flagNoEmail bool, envEmail string, persisted *Config) (Config, error) {
	flagEmail = strings.TrimSpace(flagEmail)
	envEmail = strings.TrimSpace(envEmail)
	if flagNoEmail && (flagEmail != "" || envEmail != "") {
		return Config{}, fmt.Errorf("--acme-no-email cannot be combined with an ACME email")
	}

	config := Config{}
	switch {
	case flagEmail != "":
		config.Email = flagEmail
	case envEmail != "":
		config.Email = envEmail
	case flagNoEmail:
		config.NoEmail = true
	case persisted != nil:
		config = *persisted
	}
	config.Email = strings.TrimSpace(config.Email)
	if err := config.Validate(); err != nil {
		return Config{}, err
	}
	return config, nil
}

func Parse(data []byte) (Config, error) {
	var config Config
	if err := json.Unmarshal(data, &config); err != nil {
		return Config{}, fmt.Errorf("parse ACME config: %w", err)
	}
	if err := config.Validate(); err != nil {
		return Config{}, err
	}
	return config, nil
}

func Marshal(config Config) ([]byte, error) {
	if err := config.Validate(); err != nil {
		return nil, err
	}
	out, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(out, '\n'), nil
}
