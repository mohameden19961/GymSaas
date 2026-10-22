CREATE OR REPLACE FUNCTION public.record_payment (
  p_member_id       uuid,
  p_subscription_id uuid,
  p_amount          numeric,
  p_method          text,
  p_reference       text    DEFAULT NULL::text
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare v_gym uuid; v_staff uuid; v_pay uuid; v_sub public.subscriptions%rowtype;
begin
  select gym_id into v_gym from public.members where id = p_member_id;
  if v_gym is null then raise exception 'member not found'; end if;
  if not private.has_perm(v_gym, 'record_payments') then
    raise exception 'not allowed to record payments' using errcode = '42501';
  end if;
  select id into v_staff from public.gym_users
  where gym_id = v_gym and profile_id = (select auth.uid());

  if p_subscription_id is not null then
    select * into v_sub from public.subscriptions
    where id = p_subscription_id and gym_id = v_gym and member_id = p_member_id for update;
    if not found then raise exception 'subscription not found for this member'; end if;
    if v_sub.status = 'cancelled' then raise exception 'subscription is cancelled'; end if;
  end if;

  insert into public.payments (gym_id, member_id, subscription_id, recorded_by, amount, method, reference)
  values (v_gym, p_member_id, p_subscription_id, v_staff, p_amount, p_method, p_reference)
  returning id into v_pay;

  if p_subscription_id is not null and v_sub.status = 'pending' then
    update public.subscriptions set status = 'active' where id = p_subscription_id;
  end if;
  return v_pay;
end $function$;

GRANT EXECUTE ON FUNCTION "public"."record_payment"(uuid, uuid, numeric, text, text) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."record_payment"(uuid, uuid, numeric, text, text) TO "service_role";

REVOKE ALL ON FUNCTION "public"."record_payment"(uuid, uuid, numeric, text, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."record_payment"(uuid, uuid, numeric, text, text) TO "postgres";

REVOKE ALL ON FUNCTION "public"."record_payment"(uuid, uuid, numeric, text, text) FROM PUBLIC, "anon";
