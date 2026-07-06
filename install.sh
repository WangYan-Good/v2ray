#!/usr/bin/env bash

set -euo pipefail

repo="${XRAY_REPO:-WangYan-Good/xray}"
version="${XRAY_VERSION:-latest}"
proxy=""
tls_mode="nginx"
core_version=""
core_file=""
skip_core=0

usage() {
    cat <<'USAGE'
Usage: install.sh [--tls nginx|caddy] [--proxy URL] [--version TAG] [--core-version TAG] [--core-file FILE] [--skip-core]

Installs the xray Go CLI to /usr/local/bin/xray, then runs:
  xray install

Remote one-line install remains supported:
  bash <(curl -Ls https://raw.githubusercontent.com/WangYan-Good/xray/main/install.sh)
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    --tls)
        tls_mode="${2:-}"
        shift 2
        ;;
    -p | --proxy)
        proxy="${2:-}"
        shift 2
        ;;
    -v | --version)
        version="${2:-}"
        shift 2
        ;;
    --core-version)
        core_version="${2:-}"
        shift 2
        ;;
    -f | --core-file)
        core_file="${2:-}"
        shift 2
        ;;
    --skip-core)
        skip_core=1
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
done

if [[ ${EUID} -ne 0 ]]; then
    echo "error: install.sh must run as root" >&2
    exit 3
fi

case "$(uname -m)" in
x86_64 | amd64)
    go_arch="amd64"
    ;;
aarch64 | arm64 | armv8*)
    go_arch="arm64"
    ;;
*)
    echo "error: unsupported architecture: $(uname -m)" >&2
    exit 4
    ;;
esac

if [[ -n "$proxy" ]]; then
    export http_proxy="$proxy" https_proxy="$proxy" HTTP_PROXY="$proxy" HTTPS_PROXY="$proxy"
fi

need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "error: missing required command: $1" >&2
        exit 5
    fi
}

need_cmd curl
need_cmd tar
need_cmd sha256sum

base_url="https://github.com/${repo}/releases"
if [[ "$version" == "latest" || -z "$version" ]]; then
    download_base="${base_url}/latest/download"
else
    download_base="${base_url}/download/${version}"
fi

asset="xray-linux-${go_arch}.tar.gz"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "Downloading ${asset} from ${download_base}"
curl -fL --retry 3 --connect-timeout 20 -o "${tmpdir}/${asset}" "${download_base}/${asset}"
curl -fL --retry 3 --connect-timeout 20 -o "${tmpdir}/checksums.txt" "${download_base}/checksums.txt"

(
    cd "$tmpdir"
    grep " ${asset}$" checksums.txt | sha256sum -c -
)

tar -xzf "${tmpdir}/${asset}" -C "$tmpdir"
install -m 0755 "${tmpdir}/xray" /usr/local/bin/xray

install_args=(install --tls "$tls_mode")
if [[ -n "$core_version" ]]; then
    install_args+=(--core-version "$core_version")
fi
if [[ -n "$core_file" ]]; then
    install_args+=(--core-file "$core_file")
fi
if [[ -n "$proxy" ]]; then
    install_args+=(--proxy "$proxy")
fi
if [[ "$skip_core" -eq 1 ]]; then
    install_args+=(--skip-core)
fi

echo "Running: /usr/local/bin/xray ${install_args[*]}"
/usr/local/bin/xray "${install_args[@]}"

echo "xray installation complete"
