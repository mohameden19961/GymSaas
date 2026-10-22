CREATE TABLE "public"."advertisements" (
  "id"         uuid NOT NULL DEFAULT gen_random_uuid(),
  "title"      text NOT NULL,
  "content"    text,
  "start_date" date NOT NULL,
  "end_date"   date NOT NULL,
  "status"     text NOT NULL DEFAULT 'draft'::text,
  CONSTRAINT "ads_dates_ck" CHECK ((end_date >= start_date)),
  CONSTRAINT "advertisements_pkey" PRIMARY KEY (id),
  CONSTRAINT "advertisements_status_check" CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'paused'::text, 'ended'::text])))
);

ALTER TABLE "public"."advertisements"
  ENABLE ROW LEVEL SECURITY;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."advertisements" TO "service_role";

REVOKE ALL ON TABLE "public"."advertisements" FROM "anon";

GRANT MAINTAIN ON TABLE "public"."advertisements" TO "anon";

REVOKE ALL ON TABLE "public"."advertisements" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."advertisements" TO "authenticated";

REVOKE ALL ON TABLE "public"."advertisements" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."advertisements" TO "postgres";
