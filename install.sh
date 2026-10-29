#!/usr/bin/env bash
# Fresh installations only. Never imports, prints or uploads node keys.
set -Eeuo pipefail
umask 077
SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
UPSTREAM=https://github.com/QuipNetwork/nodes.quip.network.git
REVISION=62083da02a79b6e087149504d11f220af2a05400
ROOT=/opt/quip-node
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
trap 'printf "Stopped at line %s. Runtime files are retained; no automatic deletion.\n" "$LINENO" >&2' ERR
[[ ${1:-} != --help ]] || { printf 'Run: sudo bash install.sh\nFresh Ubuntu/Debian x86_64 host; CPU-only installation, domain, email, moniker, points address and limits.\nRuntime: /opt/quip-node. Requires working Docker Engine + Compose v2.\n'; exit 0; }
[[ $EUID == 0 ]] || die 'Run sudo bash install.sh.'
[[ $(uname -m) == x86_64 ]] || die 'This installer targets x86_64 Linux.'
[[ -r /etc/os-release ]] || die 'Missing /etc/os-release.'
. /etc/os-release
[[ $ID == ubuntu || $ID == debian ]] || die 'Ubuntu or Debian required.'
[[ ! -e $ROOT ]] || die "$ROOT already exists. Refusing to replace any installation."
[[ -t 0 ]] || die 'Run from a terminal, not curl | bash.'
for cmd in docker git python3 curl ss; do command -v "$cmd" >/dev/null || die "Install prerequisite: $cmd (see README)."; done
docker info >/dev/null
docker compose version >/dev/null
[[ -z $(docker ps -a --format '{{.Names}}' | grep -E '^quip-' || true) ]] || die 'Existing Quip containers found; use a different host.'
[[ -z $(docker volume ls --format '{{.Name}}' | grep -E '^(aglais-pgdata|quip-caddy-data|quip-caddy-config)$' || true) ]] || die 'Existing Quip volumes found; refusing to reuse identities/settings.'
for port in 80 443 20049 30333; do
  [[ -z $(ss -H -ltn "sport = :$port") ]] || die "TCP $port already in use."
done
for port in 30333 5514; do
  [[ -z $(ss -H -lun "sport = :$port") ]] || die "UDP $port already in use."
done
PROFILE=cpu
read -rp 'Domain pointing directly to this server (example: node.example.org): ' DOMAIN
DOMAIN=${DOMAIN,,}
read -rp "Email for Let's Encrypt: " EMAIL
read -rp 'Moniker (ASCII, max 32 characters): ' MONIKER
read -rp 'Public EVM points address (0x..., optional; Enter to skip): ' ADDRESS
TOTAL=$(nproc)
read -rp "CPU miner cores [1-$TOTAL] (2; use 1 on a single-core host): " CPUS
CPUS=${CPUS:-2}
[[ $CPUS =~ ^[1-9][0-9]*$ ]] && (( CPUS <= TOTAL )) || die 'Invalid CPU count.'
RAM_GB=$(awk '/MemTotal/ {print int($2/1048576)}' /proc/meminfo)
read -rp "CPU miner RAM ceiling in GiB (host: $RAM_GB GiB, default 4): " MEMORY
MEMORY=${MEMORY:-4}
[[ $MEMORY =~ ^[1-9][0-9]*$ ]] && (( MEMORY + 2 <= RAM_GB )) || die 'Leave at least 2 GiB for other services; choose a lower miner ceiling or larger host.'
read -rp 'Descriptor public port [20049/443] (20049): ' PORT
PORT=${PORT:-20049}
[[ $PORT == 20049 || $PORT == 443 ]] || die 'Choose 20049 or 443.'
python3 -c 'import socket,sys; print("DNS:", sorted({x[4][0] for x in socket.getaddrinfo(sys.argv[1],None)}))' "$DOMAIN"
printf 'Verify the displayed DNS points to THIS server; remove stale AAAA records.\nOpen TCP 80,443,20049,30333 and UDP 30333 in provider firewall.\n'
read -rp 'DNS and external firewall ready? [yes/no]: ' READY
[[ $READY == yes ]] || die 'Fix DNS/firewall, then rerun.'
(umask 022; git clone "$UPSTREAM" "$ROOT")
git -C "$ROOT" checkout --detach "$REVISION"
python3 "$SOURCE_DIR/configure.py" --root "$ROOT" --domain "$DOMAIN" --email "$EMAIL" --name "$MONIKER" --address "$ADDRESS" --profile "$PROFILE" --cpus "$CPUS" --memory "$MEMORY" --port "$PORT"
# Runtime checkout stays outside the public installer repository.
chown 1000:1000 "$ROOT/data" "$ROOT/data/config.toml"
chmod 755 "$ROOT" "$ROOT/data"
install -m 755 "$SOURCE_DIR/check.sh" "$ROOT/check.sh"
cd "$ROOT"
docker compose config --quiet
if [[ ${1:-} == --prepare-only ]]; then
  printf 'Prepared /opt/quip-node without starting containers. Restore private identity files before docker compose up -d.\n'
  exit 0
fi
docker compose pull
printf 'Starting the stack. Archive sync may take hours; miner/dashboard wait for validator health.\n'
docker compose up -d
bash ./check.sh || printf 'Some endpoints are not ready. Use check.sh again after TLS/sync completes.\n'
printf '\nDashboard: https://%s\nRuntime: %s\nInspect: cd %s && sudo bash check.sh\n' "$DOMAIN" "$ROOT" "$ROOT"
