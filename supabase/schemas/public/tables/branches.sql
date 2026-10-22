CREATE TABLE "public"."branches" (
  "id"     uuid NOT NULL DEFAULT gen_random_uuid(),
  "gym_id" uuid NOT NULL,
  "name"   text NOT NULL,
  "status" text NOT NULL DEFAULT 'active'::text,
  CONSTRAINT "branches_id_gym_uq" UNIQUE (id, gym_id),
  CONSTRAINT "branches_pkey" PRIMARY KEY (id),
  CONSTRAINT "branches_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text]))),
  CONSTRAINT "branches_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES public.gyms(id)
);

ALTER TABLE "public"."branches"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX branches_gym_id_idx ON public.branches USING btree (gym_id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."branches" TO "service_role";

REVOKE ALL ON TABLE "public"."branches" FROM "anon";

GRANT MAINTAIN ON TABLE "public"."branches" TO "anon";

REVOKE ALL ON TABLE "public"."branches" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."branches" TO "authenticated";

REVOKE ALL ON TABLE "public"."branches" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."branches" TO "postgres";
