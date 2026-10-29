#!/usr/bin/env python3
"""Render validated public-node settings into a NEW runtime checkout only."""
import argparse
import json
import pathlib
import re

def render(root, domain, email, name, address, profile, cpus, memory, port):
    if not re.fullmatch(r'(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}', domain):
        raise ValueError('Use a DNS hostname only, without https, path, port or wildcard.')
    if not re.fullmatch(r'[A-Za-z0-9._+%-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,63}', email):
        raise ValueError('Invalid certificate email.')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9 _.-]{0,31}', name):
        raise ValueError('Moniker: 1-32 ASCII letters, numbers, spaces, dot, dash or underscore.')
    if address and not re.fullmatch(r'0x[0-9a-fA-F]{40}', address):
        raise ValueError('Points address must be a public 0x address (40 hex digits).')
    if profile != 'cpu' or not 1 <= cpus <= 4096 or memory < 1 or port not in (443, 20049):
        raise ValueError('Invalid resource/profile/port setting.')
    root = pathlib.Path(root)
    if (root / '.env').exists() or (root / 'data/config.toml').exists() or (root / 'data/keystore.json').exists():
        raise ValueError('Existing runtime settings or identity found; refusing to overwrite.')
    node_name = name + (' - ' + address if address else '')
    env = dict(CHANNEL='beta', COMPOSE_PROFILES=profile, PUID='1000', PGID='1000',
               QUIP_HOSTNAME=f'{domain}, {domain}:20049', CERT_EMAIL=email,
               VALIDATOR_NAME=node_name, QUIP_MINER_CPUSET='0' if cpus == 1 else f'0-{cpus-1}',
               QUIP_MINER_MEM_LIMIT=f'{memory}g')
    miner = f'''[miner]
validators = ["ws://quip-validator:9944"]
faucet_url = "https://faucet.aglais.quip.network"
signer_key = "/data/keystore.json"
public_host = {json.dumps(domain)}
public_port = {port}
node_name = {json.dumps(node_name)}
auto_mine = true
log_level = "info"

'''
    miner += f'[cpu]\nbinary = "quip-cpu-sa"\nnum_cpus = {cpus}\n'
    miner += '\n[dashboard]\nlisten = "0.0.0.0:8086"\ndata_dir = "/data/attempts"\n'
    (root / 'data').mkdir(parents=True, exist_ok=True)
    (root / '.env').write_text(''.join(f"{k}='{v}'\n" for k, v in env.items()))
    (root / '.env').chmod(0o600)
    (root / 'data/config.toml').write_text(miner)
    (root / 'data/config.toml').chmod(0o644)
    return env, miner

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('root', 'domain', 'email', 'name', 'profile'):
        p.add_argument('--' + key, required=True)
    p.add_argument('--address', default='')
    for key in ('cpus', 'memory', 'port'):
        p.add_argument('--' + key, required=True, type=int)
    a = p.parse_args()
    try:
        render(**vars(a))
    except ValueError as e:
        p.error(str(e))
