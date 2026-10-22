CREATE OR REPLACE FUNCTION private.is_super_admin()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select coalesce(((select auth.jwt()) -> 'app_metadata') ->> 'role', '') = 'super_admin'
$function$;
