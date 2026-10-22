CREATE OR REPLACE FUNCTION private.has_perm (
  p_gym  uuid,
  p_perm text
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select exists (
    select 1
    from public.gym_users gu
    join public.gyms g on g.id = gu.gym_id and g.status = 'active'
    where gu.gym_id = p_gym
      and gu.profile_id = (select auth.uid())
      and (gu.role = 'gym_owner' or coalesce(gu.permissions ->> p_perm, 'false') = 'true')
  )
$function$;
