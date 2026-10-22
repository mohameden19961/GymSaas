CREATE OR REPLACE FUNCTION private.gym_role (
  p_gym uuid
)
  RETURNS text
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select gu.role
  from public.gym_users gu
  join public.gyms g on g.id = gu.gym_id and g.status = 'active'
  where gu.gym_id = p_gym and gu.profile_id = (select auth.uid())
  limit 1
$function$;
