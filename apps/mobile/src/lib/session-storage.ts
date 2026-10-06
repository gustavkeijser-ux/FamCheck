import AsyncStorage from '@react-native-async-storage/async-storage';
import { getRandomBytes } from 'expo-crypto';
import * as SecureStore from 'expo-secure-store';

import { createEncryptedStorage } from './encrypted-storage';

/** Sessionslagringen som används av Supabase-klienten i appen. */
export const sessionStorage = createEncryptedStorage({
  secureStore: {
    getItem: (key) => SecureStore.getItemAsync(key),
    setItem: (key, value) =>
      SecureStore.setItemAsync(key, value, {
        // Nyckeln följer inte med i säkerhetskopior eller till en ny enhet.
        keychainAccessible: SecureStore.AFTER_FIRST_UNLOCK_THIS_DEVICE_ONLY,
      }),
    removeItem: (key) => SecureStore.deleteItemAsync(key),
  },
  valueStore: AsyncStorage,
  randomBytes: getRandomBytes,
});
