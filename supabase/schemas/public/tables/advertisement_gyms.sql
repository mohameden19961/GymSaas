CREATE TABLE "public"."advertisement_gyms" (
  "advertisement_id" uuid NOT NULL,
  "gym_id"           uuid NOT NULL,
  CONSTRAINT "advertisement_gyms_pkey" PRIMARY KEY (advertisement_id, gym_id),
  CONSTRAINT "advertisement_gyms_advertisement_id_fkey" FOREIGN KEY (advertisement_id) REFERENCES public.advertisements(id) ON DELETE CASCADE,
  CONSTRAINT "advertisement_gyms_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES public.gyms(id)
);

ALTER TABLE "public"."advertisement_gyms"
  ENABLE ROW LEVEL SECURITY;

CREATE INDEX advertisement_gyms_gym_id_idx ON public.advertisement_gyms USING btree (gym_id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."advertisement_gyms" TO "service_role";

REVOKE ALL ON TABLE "public"."advertisement_gyms" FROM "anon";

GRANT MAINTAIN ON TABLE "public"."advertisement_gyms" TO "anon";

REVOKE ALL ON TABLE "public"."advertisement_gyms" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE "public"."advertisement_gyms" TO "authenticated";

REVOKE ALL ON TABLE "public"."advertisement_gyms" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."advertisement_gyms" TO "postgres";
