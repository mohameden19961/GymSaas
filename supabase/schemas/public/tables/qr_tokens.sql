CREATE TABLE "public"."qr_tokens" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "gym_id"     uuid                     NOT NULL,
  "member_id"  uuid                     NOT NULL,
  "nonce"      text                     NOT NULL,
  "expires_at" timestamp with time zone NOT NULL,
  "used_at"    timestamp with time zone,
  CONSTRAINT "qr_id_gym_uq" UNIQUE (id, gym_id),
  CONSTRAINT "qr_member_fk" FOREIGN KEY (member_id, gym_id) REFERENCES public.members(id, gym_id),
  CONSTRAINT "qr_tokens_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES public.gyms(id),
  CONSTRAINT "qr_tokens_nonce_key" UNIQUE (nonce),
  CONSTRAINT "qr_tokens_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."qr_tokens"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX qr_tokens_member_id_idx ON public.qr_tokens USING btree (member_id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."qr_tokens" TO "service_role";

REVOKE ALL ON TABLE "public"."qr_tokens" FROM "anon";

GRANT MAINTAIN ON TABLE "public"."qr_tokens" TO "anon";

REVOKE ALL ON TABLE "public"."qr_tokens" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."qr_tokens" TO "authenticated";

REVOKE ALL ON TABLE "public"."qr_tokens" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."qr_tokens" TO "postgres";
