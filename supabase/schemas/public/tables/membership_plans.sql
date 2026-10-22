CREATE TABLE "public"."membership_plans" (
  "id"            uuid          NOT NULL DEFAULT gen_random_uuid(),
  "gym_id"        uuid          NOT NULL,
  "name"          text          NOT NULL,
  "price"         numeric(12,2) NOT NULL,
  "duration_days" integer       NOT NULL,
  "is_active"     boolean       NOT NULL DEFAULT true,
  CONSTRAINT "membership_plans_duration_days_check" CHECK ((duration_days > 0)),
  CONSTRAINT "membership_plans_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES public.gyms(id),
  CONSTRAINT "membership_plans_pkey" PRIMARY KEY (id),
  CONSTRAINT "membership_plans_price_check" CHECK ((price >= (0)::numeric)),
  CONSTRAINT "plans_id_gym_uq" UNIQUE (id, gym_id)
);

ALTER TABLE "public"."membership_plans"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX membership_plans_gym_id_idx ON public.membership_plans USING btree (gym_id);

CREATE TRIGGER audit_plans
  AFTER INSERT OR DELETE OR UPDATE ON public.membership_plans
  FOR EACH ROW
  EXECUTE FUNCTION private.audit_row();

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."membership_plans" TO "service_role";

REVOKE ALL ON TABLE "public"."membership_plans" FROM "anon";

GRANT MAINTAIN ON TABLE "public"."membership_plans" TO "anon";

REVOKE ALL ON TABLE "public"."membership_plans" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."membership_plans" TO "authenticated";

REVOKE ALL ON TABLE "public"."membership_plans" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."membership_plans" TO "postgres";
