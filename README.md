# Xray

> 一个支持多站点共存的 Xray 一键安装和管理脚本

> **本项目 Fork 自**: [233boy/v2ray](https://github.com/233boy/v2ray)

本项目使用 Go 进行了重构，并增加了 Nginx + Certbot 来配置 TLS 证书。

## 安装教程

```bash
bash <(curl -Ls https://raw.githubusercontent.com/WangYan-Good/xray/main/install.sh)
```

Options:

```bash
bash install.sh --tls nginx
bash install.sh --tls caddy
bash install.sh --proxy http://127.0.0.1:7890
bash install.sh --version v2.0.0-release
bash install.sh --core-version v26.3.27
```

## 命令参考

```bash
xray version
xray status
xray add vws example.com
xray add vxhttp 10004 11111111-1111-4111-8111-111111111111 example.com /xray-test
xray add reality 10001 11111111-1111-4111-8111-111111111111 www.microsoft.com
xray info vless
xray url vless
xray client vless > client.json
xray mihomo
xray refresh-sub example.com
xray sub-url example.com
xray del vless
xray test
xray restart
```

## 参考文档

参考 [项目文档入口](./docs/README.md)
