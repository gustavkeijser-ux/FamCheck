import * as aesjs from 'aes-js';

/**
 * Krypterad nyckel/värde-lagring för Supabase-sessionen (se AUTH_AND_IDENTITY.md §3).
 *
 * SecureStore (Keychain/Keystore) har en storleksgräns som en session kan
 * överskrida. Därför sparas en slumpad AES-256-nyckel per post i SecureStore och
 * den krypterade sessionen i AsyncStorage. Utan nyckeln i Keychain/Keystore är
 * datan i AsyncStorage oläslig.
 *
 * Beroendena injiceras så att logiken kan testas utan native-moduler.
 */
export interface KeyValueStore {
  getItem(key: string): Promise<string | null>;
  setItem(key: string, value: string): Promise<void>;
  removeItem(key: string): Promise<void>;
}

export interface EncryptedStorageDeps {
  /** Säker lagring för nycklar (expo-secure-store i appen). */
  secureStore: KeyValueStore;
  /** Lagring för krypterade värden (AsyncStorage i appen). */
  valueStore: KeyValueStore;
  /** Kryptografiskt säkra slumpbytes. */
  randomBytes: (length: number) => Uint8Array;
}

const KEY_PREFIX = 'famcheck.enc-key.';
const VALUE_PREFIX = 'famcheck.enc-value.';

/** SecureStore tillåter bara [A-Za-z0-9._-] i nycklar. */
function safeKey(key: string): string {
  return key.replace(/[^A-Za-z0-9._-]/g, '_');
}

export function createEncryptedStorage({
  secureStore,
  valueStore,
  randomBytes,
}: EncryptedStorageDeps) {
  async function encrypt(key: string, value: string): Promise<string> {
    const encryptionKey = randomBytes(256 / 8);
    const iv = randomBytes(16);
    const cipher = new aesjs.ModeOfOperation.ctr(encryptionKey, new aesjs.Counter(iv));
    const encrypted = cipher.encrypt(aesjs.utils.utf8.toBytes(value));

    await secureStore.setItem(KEY_PREFIX + safeKey(key), aesjs.utils.hex.fromBytes(encryptionKey));
    return `${aesjs.utils.hex.fromBytes(iv)}:${aesjs.utils.hex.fromBytes(encrypted)}`;
  }

  async function decrypt(key: string, stored: string): Promise<string | null> {
    const keyHex = await secureStore.getItem(KEY_PREFIX + safeKey(key));
    const [ivHex, dataHex] = stored.split(':');
    if (!keyHex || !ivHex || !dataHex) return null;

    const cipher = new aesjs.ModeOfOperation.ctr(
      aesjs.utils.hex.toBytes(keyHex),
      new aesjs.Counter(aesjs.utils.hex.toBytes(ivHex)),
    );
    return aesjs.utils.utf8.fromBytes(cipher.decrypt(aesjs.utils.hex.toBytes(dataHex)));
  }

  return {
    async getItem(key: string): Promise<string | null> {
      const stored = await valueStore.getItem(VALUE_PREFIX + key);
      if (!stored) return null;
      try {
        return await decrypt(key, stored);
      } catch {
        // Korrupt eller ofullständig post (t.ex. nyckeln raderad) → behandla som utloggad.
        return null;
      }
    },
    async setItem(key: string, value: string): Promise<void> {
      const encrypted = await encrypt(key, value);
      await valueStore.setItem(VALUE_PREFIX + key, encrypted);
    },
    async removeItem(key: string): Promise<void> {
      await valueStore.removeItem(VALUE_PREFIX + key);
      await secureStore.removeItem(KEY_PREFIX + safeKey(key));
    },
  };
}
