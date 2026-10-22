CREATE TABLE "public"."gyms" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "name"       text                     NOT NULL,
  "status"     text                     NOT NULL DEFAULT 'active'::text,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "gyms_pkey" PRIMARY KEY (id),
  CONSTRAINT "gyms_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'suspended'::text])))
);

ALTER TABLE "public"."gyms"
  ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER audit_gyms
  AFTER INSERT OR DELETE OR UPDATE ON public.gyms
  FOR EACH ROW
  EXECUTE FUNCTION private.audit_row();

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."gyms" TO "service_role";

REVOKE ALL ON TABLE "public"."gyms" FROM "anon";

GRANT MAINTAIN ON TABLE "public"."gyms" TO "anon";

REVOKE ALL ON TABLE "public"."gyms" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."gyms" TO "authenticated";

REVOKE ALL ON TABLE "public"."gyms" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."gyms" TO "postgres";
