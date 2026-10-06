/**
 * Integrationstester mot den lokala Supabase-stacken. Körs i ren Node (utan
 * jest-expo, som ersätter global fetch med en React Native-variant).
 * @type {import('jest').Config}
 */
module.exports = {
  testEnvironment: 'node',
  testMatch: ['<rootDir>/src/**/*.integration.test.ts'],
  transform: { '^.+\\.[jt]sx?$': 'babel-jest' },
  transformIgnorePatterns: ['node_modules/(?!(@famcheck)/)'],
  moduleNameMapper: { '^@/(.*)$': '<rootDir>/src/$1' },
};
