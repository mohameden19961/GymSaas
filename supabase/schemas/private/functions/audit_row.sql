CREATE OR REPLACE FUNCTION private.audit_row()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare v_old jsonb; v_new jsonb; v_gym uuid;
begin
  if tg_op in ('UPDATE','DELETE') then v_old := to_jsonb(old); end if;
  if tg_op in ('INSERT','UPDATE') then v_new := to_jsonb(new); end if;
  if tg_table_name = 'gyms' then
    v_gym := coalesce((v_new ->> 'id')::uuid, (v_old ->> 'id')::uuid);
  else
    v_gym := coalesce((v_new ->> 'gym_id')::uuid, (v_old ->> 'gym_id')::uuid);
  end if;
  insert into public.audit_logs (gym_id, actor_id, action, entity, old_values, new_values)
  values (v_gym, (select auth.uid()), tg_op, tg_table_name, v_old, v_new);
  return null;
end $function$;
