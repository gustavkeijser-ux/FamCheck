// Platshållare – ersätts av `pnpm gen:types` när kärnmigreringarna finns.
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];
export type Database = Record<string, never>;
