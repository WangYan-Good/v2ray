#!/bin/bash
# Fix quote issues in core.sh - Round 2

FILE="/home/node/.openclaw/v2ray/src/core.sh"

# Create backup
cp "$FILE" "$FILE.bak.20260325_round2"

# Read the file and fix line by line
awk '
1417 { print "                IS_SERVER_ID_JSON=\"settings:{clients:[{id:\\\"$UUID\\\"}],detour:{to:\\\"$IS_CONFIG_NAME-link.json\\\"}}\""; next }
1419 { print "                IS_SERVER_ID_JSON=\"settings:{clients:[{id:\\\"$UUID\\\"}]}\""; next }
1421 { print "            IS_CLIENT_ID_JSON=\"settings:{vnext:[{address:\\\"$IS_ADDR\\\",port:\\\"$PORT\\\",users:[{id:\\\"$UUID\\\"}]}]}\""; next }
1425 { print "            IS_SERVER_ID_JSON=\"settings:{clients:[{id:\\\"$UUID\\\"}],decryption:\\\"none\\\"}\""; next }
1426 { print "            IS_CLIENT_ID_JSON=\"settings:{vnext:[{address:\\\"$IS_ADDR\\\",port:\\\"$PORT\\\",users:[{id:\\\"$UUID\\\",encryption:\\\"none\\\"}]}]}\""; next }
1428 { print "                IS_SERVER_ID_JSON=\"settings:{clients:[{id:\\\"$UUID\\\",flow:\\\"xtls-rprx-vision\\\"}],decryption:\\\"none\\\"}\""; next }
1429 { print "                IS_CLIENT_ID_JSON=\"settings:{vnext:[{address:\\\"$IS_ADDR\\\",port:\\\"$PORT\\\",users:[{id:\\\"$UUID\\\",encryption:\\\"none\\\",flow:\\\"xtls-rprx-vision\\\"}]}]}\""; next }
1435 { print "            IS_SERVER_ID_JSON=\"settings:{clients:[{password:\\\"$TROJAN_PASSWORD\\\"}]}\""; next }
1436 { print "            IS_CLIENT_ID_JSON=\"settings:{servers:[{address:\\\"$IS_ADDR\\\",port:\\\"$PORT\\\",password:\\\"$TROJAN_PASSWORD\\\"}]}\""; next }
1447 { print "            IS_CLIENT_ID_JSON=\"settings:{servers:[{address:\\\"$IS_ADDR\\\",port:\\\"$PORT\\\",method:\\\"$SS_METHOD\\\",password:\\\"$SS_PASSWORD\\\",}]}\""; next }
1448 { print "            JSON_STR=\"settings:{method:\\\"$SS_METHOD\\\",password:\\\"$SS_PASSWORD\\\",network:\\\"tcp,udp\\\"}\""; next }
1453 { print "            JSON_STR=\"settings:{port:\\\"$DOOR_PORT\\\",address:\\\"$DOOR_ADDR\\\",network:\\\"tcp,udp\\\"}\""; next }
1458 { print "            JSON_STR=\"settings:{\\\"timeout\\\": 233}\""; next }
1465 { print "            JSON_STR=\"settings:{auth:\\\"password\\\",accounts:[{user:\\\"$IS_SOCKS_USER\\\",pass:\\\"$IS_SOCKS_PASS\\\"}],udp:true,ip:\\\"0.0.0.0\\\"}\""; next }
1476 { print "            IS_STREAM=\"streamSettings:{network:\\\"tcp\\\",tcpSettings:{header:{type:\\\"$HEADER_TYPE\\\"}}}\""; next }
1477 { print "            JSON_STR=\"\\\"$IS_SERVER_ID_JSON\\\",\\\"$IS_STREAM\\\"\""; next }
1483 { print "            IS_STREAM=\"streamSettings:{network:\\\"kcp\\\",kcpSettings:{seed:\\\"$KCP_SEED\\\",header:{type:\\\"$HEADER_TYPE\\\"}}}\""; next }
1484 { print "            JSON_STR=\"\\\"$IS_SERVER_ID_JSON\\\",\\\"$IS_STREAM\\\"\""; next }
1489 { print "            IS_STREAM=\"streamSettings:{network:\\\"quac\\\",quicSettings:{header:{type:\\\"$HEADER_TYPE\\\"}}}\""; next }
1490 { print "            JSON_STR=\"\\\"$IS_SERVER_ID_JSON\\\",\\\"$IS_STREAM\\\"\""; next }
1495 { print "            IS_STREAM=\"streamSettings:{network:\\\"ws\\\",security:\\\"$IS_TLS\\\",wsSettings:{path:\\\"$URL_PATH\\\",headers:{Host:\\\"$HOST\\\"}}}\""; next }
1496 { print "            JSON_STR=\"\\\"$IS_SERVER_ID_JSON\\\",\\\"$IS_STREAM\\\"\""; next }
1502 { print "            IS_STREAM=\"streamSettings:{network:\\\"grpc\\\",grpc_host:\\\"$HOST\\\",security:\\\"$IS_TLS\\\",grpcSettings:{serviceName:\\\"$URL_PATH\\\"}}\""; next }
1503 { print "            JSON_STR=\"\\\"$IS_SERVER_ID_JSON\\\",\\\"$IS_STREAM\\\"\""; next }
1508 { print "            IS_STREAM=\"streamSettings:{network:\\\"h2\\\",security:\\\"$IS_TLS\\\",httpSettings:{path:\\\"$URL_PATH\\\",host:[\\\"$HOST\\\"]}}\""; next }
1509 { print "            JSON_STR=\"\\\"$IS_SERVER_ID_JSON\\\",\\\"$IS_STREAM\\\"\""; next }
1515 { print "            IS_STREAM=\"streamSettings:{network:\\\"tcp\\\",security:\\\"reality\\\",realitySettings:{dest:\\\"${IS_SERVERNAME}\\:443\\\",serverNames:[\\\"${IS_SERVERNAME}\\\",\\\"\\\"],publicKey:\\\"$IS_PUBLIC_KEY\\\",privateKey:\\\"$IS_PRIVATE_KEY\\\",shortIds:[\\\"\\\"]}}\""; next }
1517 { print "                IS_STREAM=\"streamSettings:{network:\\\"tcp\\\",security:\\\"reality\\\",realitySettings:{serverName:\\\"${IS_SERVERNAME}\\\",\\\"fingerprint\\\": \\\"ios\\\",publicKey:\\\"$IS_PUBLIC_KEY\\\",\\\"shortId\\\": \\\"\\\",\\\"spiderX\\\": \\\"/\\\"}}\""; next }
1519 { print "            JSON_STR=\"\\\"$IS_SERVER_ID_JSON\\\",\\\"$IS_STREAM\\\"\""; next }
{ print }
' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"

echo "Fix complete!"
