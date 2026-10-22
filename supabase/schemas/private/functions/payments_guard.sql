CREATE OR REPLACE FUNCTION private.payments_guard()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
begin
  if tg_op = 'DELETE' then
    raise exception 'payments cannot be deleted; cancel them instead';
  end if;
  if new.gym_id <> old.gym_id or new.member_id <> old.member_id
     or new.subscription_id is distinct from old.subscription_id
     or new.recorded_by <> old.recorded_by or new.amount <> old.amount
     or new.method <> old.method or new.reference is distinct from old.reference
     or new.created_at <> old.created_at then
    raise exception 'payment fields are immutable; only status may change';
  end if;
  if old.status <> 'recorded' then
    raise exception 'payment is already %', old.status;
  end if;
  return new;
end $function$;
