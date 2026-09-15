import pathlib
import tempfile
import unittest
import tomllib
from configure import render

class ConfigTests(unittest.TestCase):
    def settings(self, root, **changes):
        a = dict(root=root, domain='node.example.org', email='ops@example.org',
                 name='my-node', address='0x' + '1'*40, profile='cpu', cpus=2, memory=4, port=20049)
        a.update(changes)
        return render(**a)

    def test_cpu_only(self):
        for profile in ('cpu',):
            with tempfile.TemporaryDirectory() as d:
                env, text = self.settings(d, profile=profile)
                t = tomllib.loads(text)
                self.assertEqual(t['miner']['public_port'], 20049)
                self.assertTrue(t['miner']['auto_mine'])
                self.assertEqual(t['dashboard']['listen'], '0.0.0.0:8086')
                self.assertEqual(env['QUIP_MINER_CPUSET'], '0-1')
                self.assertEqual('cpu' in t, profile == 'cpu')
                self.assertEqual('cuda' in t, profile == 'cuda')
                self.assertFalse((pathlib.Path(d)/'data/keystore.json').exists())
                with self.assertRaises(ValueError): self.settings(d)

    def test_reject_injection(self):
        for changes in ({'domain':'$(whoami).org'}, {'name':"bad'\nCHANNEL=evil"},
                        {'address':'private-key'}, {'email':'a@b.org\nX=1'}, {'port':9944}, {'cpus':0}, {'profile':'cuda'}):
            with tempfile.TemporaryDirectory() as d:
                with self.assertRaises(ValueError): self.settings(d, **changes)
                self.assertFalse((pathlib.Path(d)/'.env').exists())

    def test_443_optional_address(self):
        with tempfile.TemporaryDirectory() as d:
            env, text = self.settings(d, port=443, address='', cpus=1)
            self.assertEqual(tomllib.loads(text)['miner']['public_port'], 443)
            self.assertEqual(env['VALIDATOR_NAME'], 'my-node')
            self.assertEqual(env['QUIP_MINER_CPUSET'], '0')

if __name__ == '__main__': unittest.main()
