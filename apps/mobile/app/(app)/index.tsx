import { useTranslation } from 'react-i18next';
import { Button, Text, View } from 'react-native';

import { useCurrentUserEmail, useSignOut } from '@/features/auth';

/** Platshållare för inloggat läge. Onboarding och hushållsvy byggs i M2. */
export default function Home() {
  const { t } = useTranslation();
  const email = useCurrentUserEmail();
  const signOut = useSignOut();

  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', gap: 12 }}>
      <Text>{t('app.foundation')}</Text>
      <Text>{t('auth.signedInAs', { email })}</Text>
      <Button
        title={t('auth.signOut')}
        disabled={signOut.isPending}
        onPress={() => signOut.mutate()}
      />
    </View>
  );
}
