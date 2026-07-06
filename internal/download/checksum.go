package download

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
)

func SHA256Hex(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func VerifySHA256(data []byte, expected string) error {
	expected = strings.ToLower(strings.TrimSpace(strings.TrimPrefix(expected, "sha256:")))
	if expected == "" {
		return fmt.Errorf("missing expected sha256")
	}
	actual := SHA256Hex(data)
	if actual != expected {
		return fmt.Errorf("sha256 mismatch: expected %s, actual %s", expected, actual)
	}
	return nil
}

func ParseXrayDigest(text string) (string, error) {
	for _, line := range strings.Split(text, "\n") {
		if !strings.Contains(line, "SHA2-256=") {
			continue
		}
		parts := strings.SplitN(line, "SHA2-256=", 2)
		if len(parts) != 2 {
			continue
		}
		hash := firstHex(parts[1])
		if hash != "" {
			return hash, nil
		}
	}
	return "", fmt.Errorf("xray digest missing SHA2-256")
}

func ParseChecksum(text, artifact string) (string, error) {
	for _, line := range strings.Split(text, "\n") {
		if !strings.Contains(line, artifact) {
			continue
		}
		if hash := firstHex(line); hash != "" {
			return hash, nil
		}
	}
	return "", fmt.Errorf("checksum for %s not found", artifact)
}

func SelectAssetDigest(releaseJSON, artifact string) (string, error) {
	var release struct {
		Assets []struct {
			Name   string `json:"name"`
			Digest string `json:"digest"`
		} `json:"assets"`
	}
	if err := json.Unmarshal([]byte(releaseJSON), &release); err != nil {
		return "", err
	}
	for _, asset := range release.Assets {
		if asset.Name != artifact {
			continue
		}
		digest := strings.TrimPrefix(strings.TrimSpace(asset.Digest), "sha256:")
		if digest == "" {
			return "", fmt.Errorf("asset %s has no digest", artifact)
		}
		return strings.ToLower(digest), nil
	}
	return "", fmt.Errorf("asset %s not found", artifact)
}

func firstHex(text string) string {
	fields := strings.Fields(strings.TrimSpace(text))
	for _, field := range fields {
		field = strings.Trim(field, "\"' ")
		field = strings.TrimPrefix(field, "sha256:")
		if len(field) != 64 {
			continue
		}
		ok := true
		for _, r := range field {
			if !((r >= '0' && r <= '9') || (r >= 'a' && r <= 'f') || (r >= 'A' && r <= 'F')) {
				ok = false
				break
			}
		}
		if ok {
			return strings.ToLower(field)
		}
	}
	return ""
}
