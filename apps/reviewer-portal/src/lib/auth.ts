import "server-only";
import { redirect } from "next/navigation";
import { createServerSupabase } from "./supabase/server";
import { createAdminSupabase } from "./supabase/admin";
export async function requireUser(){ const sb=await createServerSupabase(); const {data}=await sb.auth.getUser(); if(!data.user) redirect("/auth/sign-in"); return {sb,user:data.user}; }
export async function requireAdmin(){ const ctx=await requireUser(); if(ctx.user.app_metadata?.tafsiri_role!=="research_admin") redirect("/pending-access"); return {...ctx,sb:createAdminSupabase()}; }
export async function reviewerContext(){ const {sb,user}=await requireUser(); const {data:profile}=await sb.from("reviewer_profiles").select("id,reviewer_code,display_name,is_active").eq("auth_user_id",user.id).maybeSingle(); return {sb,user,profile}; }
