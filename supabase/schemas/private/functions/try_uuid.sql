CREATE OR REPLACE FUNCTION private.try_uuid (
  p text
)
  RETURNS uuid
  LANGUAGE plpgsql
  IMMUTABLE
  SET search_path TO ''
  AS $function$
begin return p::uuid; exception when others then return null; end $function$;
