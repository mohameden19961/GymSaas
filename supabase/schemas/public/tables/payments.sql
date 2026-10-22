CREATE TABLE "public"."payments" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "gym_id"          uuid                     NOT NULL,
  "member_id"       uuid                     NOT NULL,
  "subscription_id" uuid,
  "recorded_by"     uuid                     NOT NULL,
  "amount"          numeric(12,2)            NOT NULL,
  "method"          text                     NOT NULL,
  "reference"       text,
  "status"          text                     NOT NULL DEFAULT 'recorded'::text,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "pay_member_fk" FOREIGN KEY (member_id, gym_id) REFERENCES public.members(id, gym_id),
  CONSTRAINT "pay_staff_fk" FOREIGN KEY (recorded_by, gym_id) REFERENCES public.gym_users(id, gym_id),
  CONSTRAINT "payments_amount_check" CHECK ((amount > (0)::numeric)),
  CONSTRAINT "payments_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES public.gyms(id),
  CONSTRAINT "payments_method_check" CHECK ((method = ANY (ARRAY['cash'::text, 'bankily'::text, 'masrvi'::text, 'sedad'::text]))),
  CONSTRAINT "payments_pkey" PRIMARY KEY (id),
  CONSTRAINT "payments_status_check" CHECK ((status = ANY (ARRAY['recorded'::text, 'cancelled'::text, 'refunded'::text]))),
  CONSTRAINT "pay_sub_fk" FOREIGN KEY (subscription_id, gym_id) REFERENCES public.subscriptions(id, gym_id)
);

ALTER TABLE "public"."payments"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX payments_gym_id_created_at_idx ON public.payments USING btree (gym_id, created_at);

CREATE INDEX payments_member_id_idx ON public.payments USING btree (member_id);

CREATE INDEX payments_subscription_id_idx ON public.payments USING btree (subscription_id);

CREATE TRIGGER audit_payments
  AFTER INSERT OR DELETE OR UPDATE ON public.payments
  FOR EACH ROW
  EXECUTE FUNCTION private.audit_row();

CREATE TRIGGER payments_immutable
  BEFORE DELETE OR UPDATE ON public.payments
  FOR EACH ROW
  EXECUTE FUNCTION private.payments_guard();

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."payments" TO "service_role";

REVOKE ALL ON TABLE "public"."payments" FROM "anon";

GRANT MAINTAIN ON TABLE "public"."payments" TO "anon";

REVOKE ALL ON TABLE "public"."payments" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."payments" TO "authenticated";

REVOKE ALL ON TABLE "public"."payments" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."payments" TO "postgres";
