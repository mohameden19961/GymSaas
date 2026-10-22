CREATE TABLE "public"."visits" (
  "id"                  uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "gym_id"              uuid                     NOT NULL,
  "member_id"           uuid                     NOT NULL,
  "branch_id"           uuid                     NOT NULL,
  "qr_token_id"         uuid,
  "checked_in_at"       timestamp with time zone NOT NULL DEFAULT now(),
  "verification_source" text                     NOT NULL DEFAULT 'qr'::text,
  CONSTRAINT "visits_branch_fk" FOREIGN KEY (branch_id, gym_id) REFERENCES public.branches(id, gym_id),
  CONSTRAINT "visits_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES public.gyms(id),
  CONSTRAINT "visits_member_fk" FOREIGN KEY (member_id, gym_id) REFERENCES public.members(id, gym_id),
  CONSTRAINT "visits_one_per_token" UNIQUE (qr_token_id),
  CONSTRAINT "visits_pkey" PRIMARY KEY (id),
  CONSTRAINT "visits_qr_fk" FOREIGN KEY (qr_token_id, gym_id) REFERENCES public.qr_tokens(id, gym_id),
  CONSTRAINT "visits_verification_source_check" CHECK ((verification_source = ANY (ARRAY['qr'::text, 'manual'::text])))
);

ALTER TABLE "public"."visits"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX visits_branch_id_idx ON public.visits USING btree (branch_id);

CREATE INDEX visits_gym_id_checked_in_at_idx ON public.visits USING btree (gym_id, checked_in_at);

CREATE INDEX visits_member_id_idx ON public.visits USING btree (member_id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."visits" TO "service_role";

REVOKE ALL ON TABLE "public"."visits" FROM "anon";

GRANT MAINTAIN ON TABLE "public"."visits" TO "anon";

REVOKE ALL ON TABLE "public"."visits" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."visits" TO "authenticated";

REVOKE ALL ON TABLE "public"."visits" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."visits" TO "postgres";
