<div align="center">

**English** | [فارسی](README.fa.md)

</div>

# Quip CPU Node Installer

Interactive installer for a new CPU-based Quip node on the Aglais spec-119 relaunch. This repository contains only public scripts and documentation. Each installation creates its own identity. This installer is for fresh servers, not for upgrading a running node.

## Requirements

- Ubuntu or Debian x86_64 with sudo access.
- Docker Engine and Docker Compose v2.
- A DNS hostname pointing directly to the server. DuckDNS works. Disable the Cloudflare proxy and remove an invalid AAAA record.
- Open these ports in the provider and server firewalls:

```text
TCP: 80, 443, 20049, 30333
UDP: 30333
```

Archive mode is enabled, so disk usage grows over time. Keep at least 2 GiB of RAM outside the miner limit. The installer stops without deleting anything if it detects an existing Quip installation, conflicting volumes, or occupied ports. The current upstream stack uses the spec-119 chain database and dashboard index; old chain data must not be reused for this genesis.

## Prepare the server

```bash
sudo apt-get update
sudo apt-get install -y git python3 curl iproute2 ca-certificates
```

Install Docker using its official [Ubuntu guide](https://docs.docker.com/engine/install/ubuntu/) or [Debian guide](https://docs.docker.com/engine/install/debian/), then verify:

```bash
sudo docker info
sudo docker compose version
```

## Install a new node

Clone this repository, enter its directory, and run:

```bash
git clone https://github.com/encoderrrr/quip-node-cpu-installer.git
cd quip-node-cpu-installer
sudo bash install.sh
```

The installer asks for the domain, certificate email, node moniker, optional public EVM points address, CPU core count, memory limit, descriptor port, and confirmation that DNS and firewall rules are ready. Enter only a public address, never a private key.

With a points address, the node name uses:

```text
moniker - 0x...
```

This naming format alone does not guarantee points.

## Configured services

The installer enables CPU mining, validator, dashboard, telemetry API, public safe RPC, and automatic TLS through Caddy. HTTPS is served on ports 443 and 20049.

Descriptor fields:

```toml
public_host = "YOUR_DOMAIN"
public_port = 20049
node_name = "YOUR_NODE_NAME"
auto_mine = true
```

`auto_mine` is descriptor metadata. Mining starts after the validator finishes syncing and the miner runs.

Public endpoints:

```text
https://YOUR_DOMAIN/
https://YOUR_DOMAIN/rpc
https://YOUR_DOMAIN/api/v1/status
```

## Status and management

Runtime files are stored at `/opt/quip-node`, separately from this installer.

```bash
cd /opt/quip-node
sudo docker compose ps -a
sudo docker compose logs --tail 100 quip-validator
sudo docker compose logs --tail 100 cpu
sudo bash check.sh
```

Initial archive sync can take hours. The dashboard may appear before the validator and miner are ready. Start or continue the stack with:

```bash
sudo docker compose up -d
```

Stop or resume only the miner:

```bash
sudo docker compose stop cpu
sudo docker compose start cpu
```

Investigate `reachable: false`, `isSyncing: true`, or RPC errors. TCP checks do not prove UDP 30333 is open.

## Change CPU count

Example for 8 cores:

```text
# /opt/quip-node/.env
QUIP_MINER_CPUSET='0-7'

# /opt/quip-node/data/config.toml
[cpu]
num_cpus = 8
```

Then recreate the miner:

```bash
cd /opt/quip-node
sudo docker compose up -d --force-recreate cpu
```

## Restore an existing node

Use a fresh destination server and a backup in the expected format.

1. Stop the old node:

```bash
cd /opt/quip-node
sudo docker compose stop
```

2. Copy the backup privately:

```bash
scp node-backup.tar.gz USER@NEW_SERVER:~/node-backup.tar.gz
```

3. Prepare the requirements, clone this repository, and run:

```bash
sudo bash restore.sh "$HOME/node-backup.tar.gz"
```

The script validates the archive, asks for the new server settings, restores both identities, and starts the node. It refuses to overwrite an existing identity.

4. After sync, verify:

```bash
cd /opt/quip-node
sudo bash check.sh
sudo docker compose logs --tail 100 cpu
```

Compare the live miner address with the old node on the same network. Keep the original archive private until restoration is confirmed.

## Existing running nodes

Do not rerun `install.sh` or `restore.sh` over a running node. This repository only prepares fresh installations. To upgrade an existing node across the Aglais spec-119 reset, preserve its identity and follow the [upstream relaunch instructions](https://github.com/QuipNetwork/nodes.quip.network#aglais-relaunch-spec-119). The upstream stack uses `data/aglais-119-chain-db` and `dashboard-data-119` for the new genesis. Verify the new node before considering removal of old chain data.

## Version and tests

The upstream checkout is pinned to:

```text
62083da02a79b6e087149504d11f220af2a05400
CHANNEL=beta
```

The source commit is fixed at the official spec-119 relaunch, but beta image tags can move. Recheck the [official upstream repository](https://github.com/QuipNetwork/nodes.quip.network) and [Node Manager releases](https://gitlab.com/quip.network/quip-node-manager/-/releases) before each new deployment.

```bash
bash -n install.sh restore.sh check.sh
python3 -m unittest -v test_configure.py
```

Python 3.11 or newer is required for unit tests.

## Public repository files

```text
README.md
README.fa.md
install.sh
restore.sh
configure.py
check.sh
test_configure.py
.gitignore
.gitattributes
```

Source: [official Quip node deployment](https://github.com/QuipNetwork/nodes.quip.network).
