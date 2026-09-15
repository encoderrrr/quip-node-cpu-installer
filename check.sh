#!/usr/bin/env bash
set -Eeuo pipefail
cd /opt/quip-node
docker compose ps -a
DOMAIN=$(python3 -c 'import pathlib; line=next(x for x in pathlib.Path(".env").read_text().splitlines() if x.startswith("QUIP_HOSTNAME=")); print(line.split("=",1)[1].strip(chr(39)).split(",")[0])')
failed=0
for path in / /api/v1/status; do
  if curl --fail --silent --show-error --max-time 20 "https://$DOMAIN$path" >/dev/null; then
    printf 'HTTPS OK: %s\n' "$path"
  else
    printf 'NOT READY: %s (check DNS, TLS and initial sync)\n' "$path"
    failed=1
  fi
done
curl --fail --silent --show-error --max-time 20 "https://$DOMAIN/rpc" -H 'Content-Type: application/json' --data '{"jsonrpc":"2.0","id":1,"method":"system_health","params":[]}' || failed=1
printf '\nExternal TCP reachability (checker sees this server IP):\n'
for port in 80 443 20049 30333; do
  printf '%s: ' "$port"
  curl --fail --silent --show-error --max-time 15 "https://check.quip.network/checkport?port=$port" || failed=1
  printf '\n'
done
printf 'Check is diagnostic; reachable:false, RPC error or isSyncing:true require attention. UDP needs a separate external test.\n'
exit "$failed"
