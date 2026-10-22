CREATE TABLE "public"."platform_subscriptions" (
  "id"         uuid          NOT NULL DEFAULT gen_random_uuid(),
  "gym_id"     uuid          NOT NULL,
  "amount"     numeric(12,2) NOT NULL,
  "start_date" date          NOT NULL,
  "end_date"   date          NOT NULL,
  "status"     text          NOT NULL DEFAULT 'pending'::text,
  CONSTRAINT "platform_subs_dates_ck" CHECK ((end_date >= start_date)),
  CONSTRAINT "platform_subscriptions_amount_check" CHECK ((amount >= (0)::numeric)),
  CONSTRAINT "platform_subscriptions_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES public.gyms(id),
  CONSTRAINT "platform_subscriptions_pkey" PRIMARY KEY (id),
  CONSTRAINT "platform_subscriptions_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'expired'::text, 'cancelled'::text])))
);

ALTER TABLE "public"."platform_subscriptions"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX platform_subscriptions_gym_id_idx ON public.platform_subscriptions USING btree (gym_id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."platform_subscriptions" TO "service_role";

REVOKE ALL ON TABLE "public"."platform_subscriptions" FROM "anon";

GRANT MAINTAIN ON TABLE "public"."platform_subscriptions" TO "anon";

REVOKE ALL ON TABLE "public"."platform_subscriptions" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."platform_subscriptions" TO "authenticated";

REVOKE ALL ON TABLE "public"."platform_subscriptions" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."platform_subscriptions" TO "postgres";
