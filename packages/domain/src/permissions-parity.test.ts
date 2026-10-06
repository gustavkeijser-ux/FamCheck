import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import { ROLE_PERMISSIONS } from './roles';

/**
 * Paritet mellan TypeScript-spegeln och databasens private.role_permissions.
 * Läser blocket mellan `-- role_permissions:begin` och `-- role_permissions:end`
 * i den migrering som definierar det.
 */
const MIGRATIONS_DIR = join(__dirname, '../../../supabase/migrations');

function readDatabasePairs(): string[] {
  const blocks = readdirSync(MIGRATIONS_DIR)
    .filter((file) => file.endsWith('.sql'))
    .sort()
    .map((file) => readFileSync(join(MIGRATIONS_DIR, file), 'utf8'))
    .map((sql) => /-- role_permissions:begin([\s\S]*?)-- role_permissions:end/.exec(sql)?.[1])
    .filter((block): block is string => block !== undefined);

  expect(blocks, 'exakt ett role_permissions-block i migreringarna').toHaveLength(1);
  const [block = ''] = blocks;
  return [...block.matchAll(/\('(\w+)',\s*'([\w.]+)'\)/g)].map(([, role, permission]) => `${role}:${permission}`);
}

describe('ROLE_PERMISSIONS ↔ private.role_permissions', () => {
  it('är identiska', () => {
    const typescriptPairs = Object.entries(ROLE_PERMISSIONS).flatMap(([role, permissions]) =>
      permissions.map((permission) => `${role}:${permission}`),
    );
    expect(readDatabasePairs().sort()).toEqual(typescriptPairs.sort());
  });
});
