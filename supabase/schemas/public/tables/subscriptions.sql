CREATE TABLE "public"."subscriptions" (
  "id"         uuid NOT NULL DEFAULT gen_random_uuid(),
  "gym_id"     uuid NOT NULL,
  "member_id"  uuid NOT NULL,
  "plan_id"    uuid NOT NULL,
  "start_date" date NOT NULL DEFAULT CURRENT_DATE,
  "end_date"   date NOT NULL,
  "status"     text NOT NULL DEFAULT 'pending'::text,
  CONSTRAINT "subs_dates_ck" CHECK ((end_date >= start_date)),
  CONSTRAINT "subs_id_gym_uq" UNIQUE (id, gym_id),
  CONSTRAINT "subs_member_fk" FOREIGN KEY (member_id, gym_id) REFERENCES public.members(id, gym_id),
  CONSTRAINT "subs_plan_fk" FOREIGN KEY (plan_id, gym_id) REFERENCES public.membership_plans(id, gym_id),
  CONSTRAINT "subscriptions_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES public.gyms(id),
  CONSTRAINT "subscriptions_pkey" PRIMARY KEY (id),
  CONSTRAINT "subscriptions_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'expired'::text, 'suspended'::text, 'cancelled'::text])))
);

ALTER TABLE "public"."subscriptions"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX subscriptions_gym_id_status_end_date_idx ON public.subscriptions USING btree (gym_id, status, end_date);

CREATE INDEX subscriptions_member_id_idx ON public.subscriptions USING btree (member_id);

CREATE INDEX subscriptions_plan_id_idx ON public.subscriptions USING btree (plan_id);

CREATE TRIGGER audit_subscriptions
  AFTER INSERT OR DELETE OR UPDATE ON public.subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION private.audit_row();

CREATE TRIGGER subscriptions_end_date
  BEFORE INSERT ON public.subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION private.subscriptions_set_end_date();

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."subscriptions" TO "service_role";

REVOKE ALL ON TABLE "public"."subscriptions" FROM "anon";

GRANT MAINTAIN ON TABLE "public"."subscriptions" TO "anon";

REVOKE ALL ON TABLE "public"."subscriptions" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."subscriptions" TO "authenticated";

REVOKE ALL ON TABLE "public"."subscriptions" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."subscriptions" TO "postgres";
