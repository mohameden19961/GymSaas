CREATE TABLE "public"."gym_users" (
  "id"          uuid  NOT NULL DEFAULT gen_random_uuid(),
  "profile_id"  uuid  NOT NULL,
  "gym_id"      uuid  NOT NULL,
  "role"        text  NOT NULL,
  "permissions" jsonb NOT NULL DEFAULT '{"view_payments": false, "manage_members": true, "cancel_payments": false, "record_payments": true, "renew_subscriptions": true}'::jsonb,
  CONSTRAINT "gym_users_id_gym_uq" UNIQUE (id, gym_id),
  CONSTRAINT "gym_users_pkey" PRIMARY KEY (id),
  CONSTRAINT "gym_users_profile_gym_uq" UNIQUE (profile_id, gym_id),
  CONSTRAINT "gym_users_role_check" CHECK ((role = ANY (ARRAY['gym_owner'::text, 'receptionist'::text]))),
  CONSTRAINT "gym_users_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES public.gyms(id),
  CONSTRAINT "gym_users_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES public.profiles(id)
);

ALTER TABLE "public"."gym_users"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX gym_users_gym_id_idx ON public.gym_users USING btree (gym_id);

CREATE INDEX gym_users_profile_id_idx ON public.gym_users USING btree (profile_id);

CREATE TRIGGER audit_gym_users
  AFTER INSERT OR DELETE OR UPDATE ON public.gym_users
  FOR EACH ROW
  EXECUTE FUNCTION private.audit_row();

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."gym_users" TO "service_role";

REVOKE ALL ON TABLE "public"."gym_users" FROM "anon";

GRANT MAINTAIN ON TABLE "public"."gym_users" TO "anon";

REVOKE ALL ON TABLE "public"."gym_users" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."gym_users" TO "authenticated";

REVOKE ALL ON TABLE "public"."gym_users" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."gym_users" TO "postgres";
