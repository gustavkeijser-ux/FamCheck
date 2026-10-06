import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Button, StyleSheet, Text, TextInput, View } from 'react-native';

import { errorCodeOf, useRequestEmailOtp, useVerifyEmailOtp } from '../hooks/use-email-otp';

/**
 * Minimal, oformgiven inloggning med e-postkod. Finns för att verifiera auth-grunden
 * i M1 – riktig design görs i onboarding-ticketen (M2).
 */
export function SignInScreen() {
  const { t } = useTranslation();
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [sentTo, setSentTo] = useState<string | null>(null);
  const requestOtp = useRequestEmailOtp();
  const verifyOtp = useVerifyEmailOtp();

  const errorCode = errorCodeOf(sentTo ? verifyOtp.error : requestOtp.error);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>{t('auth.signIn.title')}</Text>

      {sentTo === null ? (
        <>
          <TextInput
            accessibilityLabel={t('auth.signIn.emailLabel')}
            placeholder={t('auth.signIn.emailLabel')}
            value={email}
            onChangeText={setEmail}
            autoCapitalize="none"
            autoComplete="email"
            keyboardType="email-address"
            style={styles.input}
          />
          <Button
            title={t('auth.signIn.sendCode')}
            disabled={requestOtp.isPending}
            onPress={() =>
              requestOtp.mutate(email, {
                onSuccess: ({ email: normalized }) => setSentTo(normalized),
              })
            }
          />
        </>
      ) : (
        <>
          <Text>{t('auth.signIn.codeSentTo', { email: sentTo })}</Text>
          <TextInput
            accessibilityLabel={t('auth.signIn.codeLabel')}
            placeholder="123456"
            value={code}
            onChangeText={setCode}
            keyboardType="number-pad"
            autoComplete="one-time-code"
            textContentType="oneTimeCode"
            maxLength={6}
            style={styles.input}
          />
          <Button
            title={t('auth.signIn.verify')}
            disabled={verifyOtp.isPending}
            onPress={() => verifyOtp.mutate({ email: sentTo, token: code })}
          />
          <Button title={t('auth.signIn.changeEmail')} onPress={() => setSentTo(null)} />
        </>
      )}

      {errorCode ? <Text accessibilityRole="alert">{t(`auth.errors.${errorCode}`)}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 24, gap: 12 },
  title: { fontSize: 24, fontWeight: '600' },
  input: { borderWidth: 1, borderRadius: 8, padding: 12 },
});
