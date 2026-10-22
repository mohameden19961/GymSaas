CREATE OR REPLACE FUNCTION private.is_my_member (
  p_member uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select exists (select 1 from public.members m
                 where m.id = p_member and m.profile_id = (select auth.uid()))
$function$;
