/** Används i uttömmande switch-satser så att TypeScript varnar när ett nytt fall tillkommer. */
export function assertNever(value: never, message = 'Oväntat värde'): never {
  throw new Error(`${message}: ${String(value)}`);
}
