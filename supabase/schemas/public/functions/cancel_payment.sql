CREATE OR REPLACE FUNCTION public.cancel_payment (
  p_payment_id uuid,
  p_reason     text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare v_p public.payments%rowtype;
begin
  select * into v_p from public.payments where id = p_payment_id for update;
  if not found then raise exception 'payment not found'; end if;
  if not private.has_perm(v_p.gym_id, 'cancel_payments') then
    raise exception 'not allowed to cancel payments' using errcode = '42501';
  end if;
  if coalesce(btrim(p_reason), '') = '' then raise exception 'a reason is required'; end if;
  if v_p.status <> 'recorded' then raise exception 'payment is already %', v_p.status; end if;

  update public.payments set status = 'cancelled' where id = p_payment_id;
  insert into public.audit_logs (gym_id, actor_id, action, entity, old_values, new_values)
  values (v_p.gym_id, (select auth.uid()), 'CANCEL_PAYMENT', 'payments',
          to_jsonb(v_p), jsonb_build_object('payment_id', v_p.id, 'reason', p_reason));
end $function$;

GRANT EXECUTE ON FUNCTION "public"."cancel_payment"(uuid, text) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."cancel_payment"(uuid, text) TO "service_role";

REVOKE ALL ON FUNCTION "public"."cancel_payment"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."cancel_payment"(uuid, text) TO "postgres";

REVOKE ALL ON FUNCTION "public"."cancel_payment"(uuid, text) FROM PUBLIC, "anon";
