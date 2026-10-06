import { createInstance } from 'i18next';
import { initReactI18next } from 'react-i18next';

import sv from '../locales/sv.json';

/** Svenska är primärt språk. All UI-text går via i18n från start (engelska läggs till senare). */
export const i18n = createInstance();

void i18n.use(initReactI18next).init({
  resources: { sv: { translation: sv } },
  lng: 'sv',
  fallbackLng: 'sv',
  interpolation: { escapeValue: false },
});
