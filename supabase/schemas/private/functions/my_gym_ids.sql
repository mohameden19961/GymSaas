CREATE OR REPLACE FUNCTION private.my_gym_ids()
  RETURNS SETOF uuid
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select gym_id from public.gym_users where profile_id = (select auth.uid())
  union
  select gym_id from public.members   where profile_id = (select auth.uid())
$function$;
