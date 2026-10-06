// Databastyperna genereras av `pnpm gen:types` (supabase gen types) – redigera inte database.ts.
export type { Database, Enums, Json, Tables, TablesInsert, TablesUpdate } from './database';

import type { Database } from './database';

type PublicSchema = Database['public'];

/** Argument och returtyp för en RPC i public-schemat. */
export type RpcName = keyof PublicSchema['Functions'];
export type RpcArgs<Name extends RpcName> = PublicSchema['Functions'][Name]['Args'];
export type RpcReturns<Name extends RpcName> = PublicSchema['Functions'][Name]['Returns'];
