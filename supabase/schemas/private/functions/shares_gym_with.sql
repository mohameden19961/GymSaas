CREATE OR REPLACE FUNCTION private.shares_gym_with (
  p_profile uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select exists (
    select 1 from public.gym_users me
    join public.gym_users other on other.gym_id = me.gym_id
    where me.profile_id = (select auth.uid()) and other.profile_id = p_profile
  ) or exists (
    select 1 from public.gym_users me
    join public.members m on m.gym_id = me.gym_id
    where me.profile_id = (select auth.uid()) and m.profile_id = p_profile
  )
$function$;
