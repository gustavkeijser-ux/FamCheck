import { createEncryptedStorage, type KeyValueStore } from './encrypted-storage';

function memoryStore(): KeyValueStore & { data: Map<string, string> } {
  const data = new Map<string, string>();
  return {
    data,
    getItem: async (key) => data.get(key) ?? null,
    setItem: async (key, value) => {
      data.set(key, value);
    },
    removeItem: async (key) => {
      data.delete(key);
    },
  };
}

function setup() {
  const secureStore = memoryStore();
  const valueStore = memoryStore();
  const storage = createEncryptedStorage({
    secureStore,
    valueStore,
    randomBytes: (length) => globalThis.crypto.getRandomValues(new Uint8Array(length)),
  });
  return { secureStore, valueStore, storage };
}

const SESSION_KEY = 'sb-127-auth-token';
const SESSION = JSON.stringify({
  access_token: 'a'.repeat(2000),
  refresh_token: 'r',
  user: { id: 'u' },
});

describe('createEncryptedStorage', () => {
  it('sparar och läser tillbaka ett värde', async () => {
    const { storage } = setup();
    await storage.setItem(SESSION_KEY, SESSION);
    await expect(storage.getItem(SESSION_KEY)).resolves.toBe(SESSION);
  });

  it('lagrar aldrig klartext i AsyncStorage', async () => {
    const { storage, valueStore } = setup();
    await storage.setItem(SESSION_KEY, SESSION);
    for (const value of valueStore.data.values()) {
      expect(value).not.toContain('access_token');
    }
  });

  it('lagrar bara den korta nyckeln i SecureStore, med giltiga tecken', async () => {
    const { storage, secureStore } = setup();
    await storage.setItem('sb:weird/key', SESSION);
    for (const [key, value] of secureStore.data) {
      expect(key).toMatch(/^[A-Za-z0-9._-]+$/);
      expect(value).toHaveLength(64); // 32 bytes hex
    }
  });

  it('använder ny nyckel och IV vid varje skrivning', async () => {
    const { storage, valueStore } = setup();
    await storage.setItem(SESSION_KEY, SESSION);
    const first = [...valueStore.data.values()][0];
    await storage.setItem(SESSION_KEY, SESSION);
    const second = [...valueStore.data.values()][0];
    expect(first).not.toBe(second);
  });

  it('returnerar null om nyckeln i SecureStore saknas', async () => {
    const { storage, secureStore } = setup();
    await storage.setItem(SESSION_KEY, SESSION);
    secureStore.data.clear();
    await expect(storage.getItem(SESSION_KEY)).resolves.toBeNull();
  });

  it('tar bort både värde och nyckel', async () => {
    const { storage, secureStore, valueStore } = setup();
    await storage.setItem(SESSION_KEY, SESSION);
    await storage.removeItem(SESSION_KEY);
    expect(secureStore.data.size).toBe(0);
    expect(valueStore.data.size).toBe(0);
    await expect(storage.getItem(SESSION_KEY)).resolves.toBeNull();
  });
});
