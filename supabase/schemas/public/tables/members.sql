CREATE TABLE "public"."members" (
  "id"            uuid NOT NULL DEFAULT gen_random_uuid(),
  "gym_id"        uuid NOT NULL,
  "profile_id"    uuid,
  "member_number" text NOT NULL,
  "photo_path"    text,
  "status"        text NOT NULL DEFAULT 'active'::text,
  "full_name"     text NOT NULL,
  "phone"         text,
  CONSTRAINT "members_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES public.gyms(id),
  CONSTRAINT "members_id_gym_uq" UNIQUE (id, gym_id),
  CONSTRAINT "members_number_uq" UNIQUE (gym_id, member_number),
  CONSTRAINT "members_pkey" PRIMARY KEY (id),
  CONSTRAINT "members_profile_gym_uq" UNIQUE (gym_id, profile_id),
  CONSTRAINT "members_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'blocked'::text]))),
  CONSTRAINT "members_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES public.profiles(id)
);

ALTER TABLE "public"."members"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX members_gym_id_full_name_idx ON public.members USING btree (gym_id, full_name);

CREATE INDEX members_profile_id_idx ON public.members USING btree (profile_id);

CREATE TRIGGER audit_members
  AFTER INSERT OR DELETE OR UPDATE ON public.members
  FOR EACH ROW
  EXECUTE FUNCTION private.audit_row();

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."members" TO "service_role";

REVOKE ALL ON TABLE "public"."members" FROM "anon";

GRANT MAINTAIN ON TABLE "public"."members" TO "anon";

REVOKE ALL ON TABLE "public"."members" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."members" TO "authenticated";

REVOKE ALL ON TABLE "public"."members" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."members" TO "postgres";
