# Phase 0 Fixtures

These fixtures describe stable Bash v1.x behavior for the Go refactor baseline.

They must not depend on real `/etc`, public DNS, Let's Encrypt, GitHub, systemd, or live services.

Fixed values:

- Domain: `example.com`
- UUID: `11111111-1111-4111-8111-111111111111`
- Path: `/xray-test`
- gRPC service name: `xray-grpc`
- REALITY serverName: `www.microsoft.com`
- REALITY public key: `example-public-key`
- Ports: start at `10001`

Directory map:

- `xray-conf/`: one managed Xray inbound JSON per protocol.
- `nginx/`: first-site and multi-protocol `.conf + .add` examples.
- `caddy/`: first-site and append examples.
- `certbot/`: renewal config examples for webroot and standalone.
- `mihomo/`: expected subscription YAML shape.
