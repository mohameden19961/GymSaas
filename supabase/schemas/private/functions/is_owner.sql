CREATE OR REPLACE FUNCTION private.is_owner (
  p_gym uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select private.gym_role(p_gym) = 'gym_owner'
$function$;
