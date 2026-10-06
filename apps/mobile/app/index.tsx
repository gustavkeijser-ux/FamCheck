import { useTranslation } from 'react-i18next';
import { Text, View } from 'react-native';

export default function Index() {
  const { t } = useTranslation();
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
      <Text>{t('app.name')}</Text>
      <Text>{t('app.foundation')}</Text>
    </View>
  );
}
