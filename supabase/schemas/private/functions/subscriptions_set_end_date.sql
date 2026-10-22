CREATE OR REPLACE FUNCTION private.subscriptions_set_end_date()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare v_days integer;
begin
  if new.end_date is null then
    select duration_days into v_days
    from public.membership_plans where id = new.plan_id and gym_id = new.gym_id;
    if v_days is null then raise exception 'plan not found for this gym'; end if;
    new.end_date := new.start_date + v_days;
  end if;
  return new;
end $function$;
