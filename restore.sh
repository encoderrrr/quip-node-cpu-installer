#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=/opt/quip-node
ARCHIVE=${1:-}
MINER_MEMBER=quip-node-backup/data/keystore.json
NETWORK_MEMBER=quip-node-backup/validator-network/secret_ed25519
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $EUID == 0 ]] || die 'Run with sudo.'
[[ -n $ARCHIVE ]] || die 'Usage: sudo bash restore.sh /path/to/node-backup.tar.gz'
ARCHIVE=$(readlink -f -- "$ARCHIVE")
[[ -f $ARCHIVE ]] || die 'Backup file not found.'
tar -tzf "$ARCHIVE" >/dev/null || die 'Backup archive is damaged or unsupported.'
tar -tvzf "$ARCHIVE" "$MINER_MEMBER" | grep -q '^-' || die 'Miner identity is missing or unsafe.'
tar -tvzf "$ARCHIVE" "$NETWORK_MEMBER" | grep -q '^-' || die 'Network identity is missing or unsafe.'

printf 'Enter the new server settings. The node will stay stopped until identity is restored.\n'
bash "$SOURCE_DIR/install.sh" --prepare-only
[[ ! -e $ROOT/data/keystore.json ]] || die 'Target miner identity already exists; refusing to overwrite it.'
[[ ! -e $ROOT/data/aglais-119-chain-db/chains/quip_testnet/network/secret_ed25519 ]] || die 'Target network identity already exists; refusing to overwrite it.'

RECOVERY_TMP=$(mktemp -d /tmp/quip-restore.XXXXXX)
trap 'case ${RECOVERY_TMP:-} in /tmp/quip-restore.*) rm -rf -- "$RECOVERY_TMP";; esac' EXIT
tar --no-same-owner --no-same-permissions -xzf "$ARCHIVE" -C "$RECOVERY_TMP" "$MINER_MEMBER" "$NETWORK_MEMBER"
[[ -f $RECOVERY_TMP/$MINER_MEMBER && ! -L $RECOVERY_TMP/$MINER_MEMBER ]] || die 'Unsafe miner identity in backup.'
[[ -f $RECOVERY_TMP/$NETWORK_MEMBER && ! -L $RECOVERY_TMP/$NETWORK_MEMBER ]] || die 'Unsafe network identity in backup.'
install -o 1000 -g 1000 -m 600 "$RECOVERY_TMP/$MINER_MEMBER" "$ROOT/data/keystore.json"
install -d -o 1000 -g 1000 -m 700 "$ROOT/data/aglais-119-chain-db/chains/quip_testnet/network"
install -o 1000 -g 1000 -m 600 "$RECOVERY_TMP/$NETWORK_MEMBER" "$ROOT/data/aglais-119-chain-db/chains/quip_testnet/network/secret_ed25519"
cd "$ROOT"
docker compose config --quiet
docker compose pull
docker compose up -d
printf '\nRestore started. After sync, compare the live miner address with the old node.\n'
printf 'Check: cd %s && sudo bash check.sh\n' "$ROOT"
