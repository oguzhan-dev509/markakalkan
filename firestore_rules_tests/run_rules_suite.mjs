import {spawnSync} from 'node:child_process';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const directory = path.dirname(fileURLToPath(import.meta.url));
const files = ['ip_ownership_rules.test.mjs', 'ip_trade_secret_rules.test.mjs',
  'shared_risk_server_only_rules.test.mjs',
  'canonical_tenant_brand_server_only_rules.test.mjs',
  'case_evidence_server_only_rules.test.mjs'];
const result = spawnSync(process.execPath,
  ['--test', '--test-concurrency=1', ...files],
  {cwd: directory, stdio: 'inherit', windowsHide: true});
process.exitCode = result.status ?? 1;
