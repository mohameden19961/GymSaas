CREATE OR REPLACE FUNCTION public.issue_qr_token (
  p_gym_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare v_member_id uuid; v_nonce text; v_exp timestamptz;
begin
  select id into v_member_id from public.members
  where gym_id = p_gym_id and profile_id = (select auth.uid()) and status = 'active';
  if v_member_id is null then
    raise exception 'not an active member of this gym' using errcode = '42501';
  end if;
  v_nonce := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  v_exp   := now() + interval '30 seconds';
  insert into public.qr_tokens (gym_id, member_id, nonce, expires_at)
  values (p_gym_id, v_member_id, v_nonce, v_exp);
  return jsonb_build_object('nonce', v_nonce, 'expires_at', v_exp);
end $function$;

GRANT EXECUTE ON FUNCTION "public"."issue_qr_token"(uuid) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."issue_qr_token"(uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."issue_qr_token"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."issue_qr_token"(uuid) TO "postgres";

REVOKE ALL ON FUNCTION "public"."issue_qr_token"(uuid) FROM PUBLIC, "anon";
