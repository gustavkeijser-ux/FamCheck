// GENERERAD FIL – redigera inte. Kör `pnpm gen:types` efter en ändrad migrering.
// Källa: supabase gen types typescript --local --schema public


export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  
  "public": {
          Tables: {
            "audit_log": {
                  Row: {
                    "action": string,"actor_user_id": string | null,"created_at": string,"household_id": string | null,"id": number,"metadata": NonNullable<Json>,"target_id": string | null,"target_type": string | null
                  }
                  Insert: {
                    "action": string,"actor_user_id"?: string | null,"created_at"?: string,"household_id"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"target_id"?: string | null,"target_type"?: string | null
                  }
                  Update: {
                    "action"?: string,"actor_user_id"?: string | null,"created_at"?: string,"household_id"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"target_id"?: string | null,"target_type"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"children": {
                  Row: {
                    "birth_date": string | null,"can_use_tasks_and_routines": boolean,"can_view_allowance": boolean,"can_view_calendar": boolean,"can_view_family_events": boolean,"can_view_own_balance": boolean,"can_view_savings_goals": boolean,"created_at": string,"household_id": string,"member_id": string,"updated_at": string
                  }
                  Insert: {
                    "birth_date"?: string | null,"can_use_tasks_and_routines"?: boolean,"can_view_allowance"?: boolean,"can_view_calendar"?: boolean,"can_view_family_events"?: boolean,"can_view_own_balance"?: boolean,"can_view_savings_goals"?: boolean,"created_at"?: string,"household_id": string,"member_id": string,"updated_at"?: string
                  }
                  Update: {
                    "birth_date"?: string | null,"can_use_tasks_and_routines"?: boolean,"can_view_allowance"?: boolean,"can_view_calendar"?: boolean,"can_view_family_events"?: boolean,"can_view_own_balance"?: boolean,"can_view_savings_goals"?: boolean,"created_at"?: string,"household_id"?: string,"member_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "children_member_fk"
      columns: ["household_id","member_id"]
isOneToOne: false
      referencedRelation: "household_members"
      referencedColumns: ["household_id","id"]
    }
                  ]
                },"household_invitations": {
                  Row: {
                    "accepted_at": string | null,"accepted_by": string | null,"created_at": string,"created_by": string | null,"expires_at": string,"household_id": string,"id": string,"invited_email": string | null,"revoked_at": string | null,"revoked_by": string | null,"role": Database["public"]['Enums']["member_role"],"target_member_id": string | null,"token_hash": string
                  }
                  Insert: {
                    "accepted_at"?: string | null,"accepted_by"?: string | null,"created_at"?: string,"created_by"?: string | null,"expires_at": string,"household_id": string,"id"?: string,"invited_email"?: string | null,"revoked_at"?: string | null,"revoked_by"?: string | null,"role": Database["public"]['Enums']["member_role"],"target_member_id"?: string | null,"token_hash": string
                  }
                  Update: {
                    "accepted_at"?: string | null,"accepted_by"?: string | null,"created_at"?: string,"created_by"?: string | null,"expires_at"?: string,"household_id"?: string,"id"?: string,"invited_email"?: string | null,"revoked_at"?: string | null,"revoked_by"?: string | null,"role"?: Database["public"]['Enums']["member_role"],"target_member_id"?: string | null,"token_hash"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "household_invitations_household_id_fkey"
      columns: ["household_id"]
isOneToOne: false
      referencedRelation: "households"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "household_invitations_target_fk"
      columns: ["household_id","target_member_id"]
isOneToOne: false
      referencedRelation: "household_members"
      referencedColumns: ["household_id","id"]
    }
                  ]
                },"household_members": {
                  Row: {
                    "avatar_path": string | null,"color": string | null,"created_at": string,"created_by": string | null,"display_name": string,"ended_at": string | null,"household_id": string,"id": string,"joined_at": string,"role": Database["public"]['Enums']["member_role"],"status": Database["public"]['Enums']["member_status"],"updated_at": string,"user_id": string | null
                  }
                  Insert: {
                    "avatar_path"?: string | null,"color"?: string | null,"created_at"?: string,"created_by"?: string | null,"display_name": string,"ended_at"?: string | null,"household_id": string,"id"?: string,"joined_at"?: string,"role": Database["public"]['Enums']["member_role"],"status"?: Database["public"]['Enums']["member_status"],"updated_at"?: string,"user_id"?: string | null
                  }
                  Update: {
                    "avatar_path"?: string | null,"color"?: string | null,"created_at"?: string,"created_by"?: string | null,"display_name"?: string,"ended_at"?: string | null,"household_id"?: string,"id"?: string,"joined_at"?: string,"role"?: Database["public"]['Enums']["member_role"],"status"?: Database["public"]['Enums']["member_status"],"updated_at"?: string,"user_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "household_members_household_id_fkey"
      columns: ["household_id"]
isOneToOne: false
      referencedRelation: "households"
      referencedColumns: ["id"]
    }
                  ]
                },"households": {
                  Row: {
                    "created_at": string,"created_by": string | null,"currency": string,"id": string,"name": string,"timezone": string,"updated_at": string
                  }
                  Insert: {
                    "created_at"?: string,"created_by"?: string | null,"currency"?: string,"id"?: string,"name": string,"timezone"?: string,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string | null,"currency"?: string,"id"?: string,"name"?: string,"timezone"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"profiles": {
                  Row: {
                    "avatar_path": string | null,"created_at": string,"display_name": string,"id": string,"last_active_household_id": string | null,"locale": string,"updated_at": string
                  }
                  Insert: {
                    "avatar_path"?: string | null,"created_at"?: string,"display_name": string,"id": string,"last_active_household_id"?: string | null,"locale"?: string,"updated_at"?: string
                  }
                  Update: {
                    "avatar_path"?: string | null,"created_at"?: string,"display_name"?: string,"id"?: string,"last_active_household_id"?: string | null,"locale"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "profiles_last_active_household_id_fkey"
      columns: ["last_active_household_id"]
isOneToOne: false
      referencedRelation: "households"
      referencedColumns: ["id"]
    }
                  ]
                }
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "accept_invitation":
{ Args: { "p_token": string }; Returns: string
                           },
"change_member_role":
{ Args: { "p_member_id": string,"p_role": Database["public"]['Enums']["member_role"] }; Returns: undefined
                           },
"create_child":
{ Args: { "p_birth_date"?: string,"p_color"?: string,"p_display_name": string,"p_household_id": string }; Returns: string
                           },
"create_household":
{ Args: { "p_name": string }; Returns: string
                           },
"create_invitation":
{ Args: { "p_email"?: string,"p_expires_in_days"?: number,"p_household_id": string,"p_role": Database["public"]['Enums']["member_role"],"p_target_member_id"?: string }; Returns: {
              "expires_at": string,"invitation_id": string,"token": string
            }[]
                           },
"delete_household":
{ Args: { "p_confirm_name": string,"p_household_id": string }; Returns: undefined
                           },
"leave_household":
{ Args: { "p_household_id": string }; Returns: undefined
                           },
"preview_invitation":
{ Args: { "p_token": string }; Returns: {
              "child_display_name": string,"expires_at": string,"household_name": string,"invited_by_name": string,"role": Database["public"]['Enums']["member_role"]
            }[]
                           },
"remove_member":
{ Args: { "p_member_id": string }; Returns: undefined
                           },
"revoke_invitation":
{ Args: { "p_invitation_id": string }; Returns: undefined
                           },
"update_child_permissions":
{ Args: { "p_can_use_tasks_and_routines"?: boolean,"p_can_view_allowance"?: boolean,"p_can_view_calendar"?: boolean,"p_can_view_family_events"?: boolean,"p_can_view_own_balance"?: boolean,"p_can_view_savings_goals"?: boolean,"p_member_id": string }; Returns: {
              "birth_date": string | null,
"can_use_tasks_and_routines": boolean,
"can_view_allowance": boolean,
"can_view_calendar": boolean,
"can_view_family_events": boolean,
"can_view_own_balance": boolean,
"can_view_savings_goals": boolean,
"created_at": string,
"household_id": string,
"member_id": string,
"updated_at": string
            }
                          SetofOptions: {
        from: "*"
        to: "children"
        isOneToOne: true
        isSetofReturn: false
      } },
"update_household":
{ Args: { "p_household_id": string,"p_name"?: string,"p_timezone"?: string }; Returns: undefined
                           }
          }
          Enums: {
            "member_role": "owner"|"adult"|"child"|"managed_child","member_status": "active"|"left"|"removed","resource_visibility": "private"|"adults"|"household"
          }
          CompositeTypes: {
            [_ in never]: never
          }
        }
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
    ? R
    : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I
    }
    ? I
    : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U
    }
    ? U
    : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  "public": {
          Enums: {
            "member_role": ["owner", "adult", "child", "managed_child"],"member_status": ["active", "left", "removed"],"resource_visibility": ["private", "adults", "household"]
          }
        }
} as const
