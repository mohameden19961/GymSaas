CREATE OR REPLACE FUNCTION public.verify_qr (
  p_nonce     text,
  p_branch_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_tok    public.qr_tokens%rowtype;
  v_member public.members%rowtype;
  v_sub    public.subscriptions%rowtype;
  v_visit  uuid;
  v_info   jsonb;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select * into v_tok from public.qr_tokens where nonce = p_nonce for update;   -- row lock: serialises duplicate scans
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'invalid_token');
  end if;
  if private.gym_role(v_tok.gym_id) is null then
    return jsonb_build_object('ok', false, 'reason', 'wrong_gym');
  end if;
  if not exists (select 1 from public.branches b
                 where b.id = p_branch_id and b.gym_id = v_tok.gym_id and b.status = 'active') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_branch');
  end if;

  select * into v_member from public.members where id = v_tok.member_id;
  select * into v_sub from public.subscriptions s
  where s.member_id = v_member.id and s.gym_id = v_member.gym_id
  order by (s.status = 'active') desc, s.end_date desc
  limit 1;

  v_info := jsonb_build_object(
    'full_name', v_member.full_name, 'member_number', v_member.member_number,
    'photo_path', v_member.photo_path, 'subscription_end', v_sub.end_date);

  if v_tok.used_at is not null then
    return v_info || jsonb_build_object('ok', false, 'reason', 'already_used');
  end if;
  if v_tok.expires_at <= now() then
    return v_info || jsonb_build_object('ok', false, 'reason', 'expired');
  end if;
  if v_member.status <> 'active' then
    return v_info || jsonb_build_object('ok', false, 'reason', 'member_inactive');
  end if;
  if v_sub.id is null or v_sub.status <> 'active'
     or current_date < v_sub.start_date or current_date > v_sub.end_date then
    return v_info || jsonb_build_object('ok', false, 'reason', 'subscription_inactive');
  end if;

  update public.qr_tokens set used_at = now() where id = v_tok.id;
  insert into public.visits (gym_id, member_id, branch_id, qr_token_id, verification_source)
  values (v_tok.gym_id, v_member.id, p_branch_id, v_tok.id, 'qr')
  returning id into v_visit;

  return v_info || jsonb_build_object('ok', true, 'visit_id', v_visit);
end $function$;

GRANT EXECUTE ON FUNCTION "public"."verify_qr"(text, uuid) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."verify_qr"(text, uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."verify_qr"(text, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."verify_qr"(text, uuid) TO "postgres";

REVOKE ALL ON FUNCTION "public"."verify_qr"(text, uuid) FROM PUBLIC, "anon";
