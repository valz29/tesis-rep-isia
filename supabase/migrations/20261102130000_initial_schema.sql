-- Retinazo: initial relational schema. Run against a NEW Supabase project.
-- Supabase owns auth.users, auth.uid() and the anon/authenticated/service_role roles.
-- This migration does not provision Auth providers, SMTP, a bucket, or a model.

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;
GRANT USAGE ON SCHEMA private TO authenticated, service_role;

CREATE TABLE public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role text NOT NULL DEFAULT 'professional' CHECK (role IN ('professional', 'admin')),
    full_name text CHECK (full_name IS NULL OR btrim(full_name) <> ''),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.patients (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id uuid NOT NULL DEFAULT auth.uid() REFERENCES public.profiles(id) ON DELETE RESTRICT,
    dni varchar(8) NOT NULL CHECK (dni ~ '^[0-9]{8}$'),
    first_names text NOT NULL CHECK (btrim(first_names) <> ''),
    last_names text NOT NULL CHECK (btrim(last_names) <> ''),
    birth_date date NOT NULL CHECK (birth_date <= CURRENT_DATE),
    sex text NOT NULL CHECK (sex IN ('female', 'male')),
    phone varchar(9) CHECK (phone ~ '^[0-9]{9}$'),
    address text,
    medical_history text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (owner_id, dni)
);
CREATE INDEX patients_owner_name_idx ON public.patients(owner_id, last_names, first_names);

CREATE TABLE public.evaluations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE RESTRICT,
    professional_id uuid NOT NULL DEFAULT auth.uid() REFERENCES public.profiles(id) ON DELETE RESTRICT,
    eye text NOT NULL CHECK (eye IN ('right', 'left')),
    observations text,
    status text NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'pending_analysis', 'not_gradable', 'completed')),
    not_gradable_reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (
        (status = 'not_gradable' AND btrim(coalesce(not_gradable_reason, '')) <> '')
        OR (status <> 'not_gradable' AND not_gradable_reason IS NULL)
    )
);
CREATE INDEX evaluations_patient_date_idx ON public.evaluations(patient_id, created_at DESC);
CREATE INDEX evaluations_professional_idx ON public.evaluations(professional_id);

CREATE TABLE public.evaluation_images (
    evaluation_id uuid NOT NULL REFERENCES public.evaluations(id) ON DELETE CASCADE,
    position smallint NOT NULL CHECK (position BETWEEN 1 AND 3),
    sha256 varchar(64) NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
    content_type text NOT NULL CHECK (content_type LIKE 'image/%'),
    byte_size bigint NOT NULL CHECK (byte_size > 0),
    width integer CHECK (width > 0),
    height integer CHECK (height > 0),
    storage_bucket text CHECK (storage_bucket IS NULL OR btrim(storage_bucket) <> ''),
    object_key text CHECK (object_key IS NULL OR (btrim(object_key) <> '' AND object_key !~ '^/')),
    upload_status text NOT NULL DEFAULT 'pending' CHECK (upload_status IN ('pending', 'uploaded', 'failed')),
    uploaded_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (evaluation_id, position),
    UNIQUE (evaluation_id, sha256),
    UNIQUE (storage_bucket, object_key),
    CHECK ((storage_bucket IS NULL) = (object_key IS NULL)),
    CHECK ((upload_status = 'uploaded') = (uploaded_at IS NOT NULL)),
    CHECK (upload_status <> 'uploaded' OR (storage_bucket IS NOT NULL AND object_key IS NOT NULL))
);

CREATE TABLE public.model_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    model_name text NOT NULL CHECK (btrim(model_name) <> ''),
    version text NOT NULL CHECK (btrim(version) <> ''),
    artifact_sha256 varchar(64) CHECK (artifact_sha256 ~ '^[0-9a-f]{64}$'),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (model_name, version)
);

CREATE TABLE public.icdr_grades (
    grade smallint PRIMARY KEY CHECK (grade BETWEEN 0 AND 4),
    label text NOT NULL UNIQUE CHECK (btrim(label) <> '')
);
INSERT INTO public.icdr_grades (grade, label) VALUES
    (0, 'Sin retinopatía aparente'),
    (1, 'Retinopatía diabética no proliferativa leve'),
    (2, 'Retinopatía diabética no proliferativa moderada'),
    (3, 'Retinopatía diabética no proliferativa severa'),
    (4, 'Retinopatía diabética proliferativa');

CREATE TABLE public.results (
    evaluation_id uuid PRIMARY KEY REFERENCES public.evaluations(id) ON DELETE CASCADE,
    model_version_id uuid NOT NULL REFERENCES public.model_versions(id) ON DELETE RESTRICT,
    icdr_grade smallint NOT NULL REFERENCES public.icdr_grades(grade),
    confidence double precision CHECK (confidence BETWEEN 0 AND 1),
    predicted_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX results_model_version_idx ON public.results(model_version_id);
CREATE INDEX results_grade_idx ON public.results(icdr_grade);

CREATE FUNCTION private.touch_updated_at() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;
CREATE TRIGGER profiles_updated BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();
CREATE TRIGGER patients_updated BEFORE UPDATE ON public.patients
    FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();
CREATE TRIGGER evaluations_updated BEFORE UPDATE ON public.evaluations
    FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();

-- Email verification is read from Auth, never from user-editable metadata.
CREATE FUNCTION private.is_verified_user() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = (SELECT auth.uid()) AND email_confirmed_at IS NOT NULL
    );
$$;
REVOKE ALL ON FUNCTION private.is_verified_user() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.is_verified_user() TO authenticated;

-- Application roles are stored in a protected column, not signup metadata.
CREATE FUNCTION private.is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT (SELECT private.is_verified_user()) AND EXISTS (
        SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'admin'
    );
$$;
CREATE FUNCTION private.is_professional() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT (SELECT private.is_verified_user()) AND EXISTS (
        SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'professional'
    );
$$;
REVOKE ALL ON FUNCTION private.is_admin(), private.is_professional() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.is_admin(), private.is_professional() TO authenticated;

-- An administrator is not a clinical author. Existing clinical records must be
-- reassigned/handled explicitly before changing a professional's role.
CREATE FUNCTION private.enforce_professional_role() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE target uuid;
BEGIN
    IF TG_TABLE_NAME = 'profiles' THEN
        IF NEW.role = 'admin' AND OLD.role <> NEW.role AND (
            EXISTS (SELECT 1 FROM public.patients WHERE owner_id = OLD.id)
            OR EXISTS (SELECT 1 FROM public.evaluations WHERE professional_id = OLD.id)
        ) THEN
            RAISE EXCEPTION 'A clinical author cannot become admin while owning clinical records' USING ERRCODE = '23514';
        END IF;
    ELSE
        IF TG_TABLE_NAME = 'patients' THEN target := NEW.owner_id;
        ELSE target := NEW.professional_id; END IF;
        -- Coordinate with concurrent role changes; FK separately handles a missing profile.
        PERFORM id FROM public.profiles WHERE id = target AND role = 'professional' FOR SHARE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Clinical records require a professional account' USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER profiles_role_guard BEFORE UPDATE OF role ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION private.enforce_professional_role();
CREATE TRIGGER patients_owner_role BEFORE INSERT OR UPDATE OF owner_id ON public.patients
    FOR EACH ROW EXECUTE FUNCTION private.enforce_professional_role();
CREATE TRIGGER evaluations_author_role BEFORE INSERT OR UPDATE OF professional_id ON public.evaluations
    FOR EACH ROW EXECUTE FUNCTION private.enforce_professional_role();

CREATE FUNCTION private.create_profile_for_auth_user() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    INSERT INTO public.profiles(id, full_name)
    VALUES (NEW.id, nullif(btrim(coalesce(
        NEW.raw_user_meta_data ->> 'full_name',
        NEW.raw_user_meta_data ->> 'name', ''
    )), ''));
    RETURN NEW;
END;
$$;
CREATE TRIGGER retinazo_auth_user_created AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION private.create_profile_for_auth_user();
-- Also cover accounts created before this migration.
INSERT INTO public.profiles(id, full_name)
SELECT id, nullif(btrim(coalesce(raw_user_meta_data ->> 'full_name', raw_user_meta_data ->> 'name', '')), '')
FROM auth.users ON CONFLICT (id) DO NOTHING;

-- Serialize child changes with status changes to prevent concurrent finalization
-- and image deletion from violating the three-image rule.
CREATE FUNCTION private.lock_evaluation_parent() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE target uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        target := OLD.evaluation_id;
    ELSE
        target := NEW.evaluation_id;
        IF TG_OP = 'UPDATE' AND OLD.evaluation_id <> NEW.evaluation_id THEN
            RAISE EXCEPTION 'An image or result cannot move to another evaluation' USING ERRCODE = '23514';
        END IF;
    END IF;
    PERFORM id FROM public.evaluations WHERE id = target FOR UPDATE;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER images_lock_parent BEFORE INSERT OR UPDATE OR DELETE ON public.evaluation_images
    FOR EACH ROW EXECUTE FUNCTION private.lock_evaluation_parent();
CREATE TRIGGER results_lock_parent BEFORE INSERT OR UPDATE OR DELETE ON public.results
    FOR EACH ROW EXECUTE FUNCTION private.lock_evaluation_parent();

CREATE FUNCTION private.check_evaluation() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE target uuid; current_status text; uploaded_count integer; result_count integer;
BEGIN
    IF TG_TABLE_NAME = 'evaluations' THEN
        target := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
    ELSE
        target := CASE WHEN TG_OP = 'DELETE' THEN OLD.evaluation_id ELSE NEW.evaluation_id END;
    END IF;
    SELECT status INTO current_status FROM public.evaluations WHERE id = target FOR UPDATE;
    IF NOT FOUND THEN RETURN NULL; END IF;
    SELECT count(*) INTO uploaded_count FROM public.evaluation_images
        WHERE evaluation_id = target AND upload_status = 'uploaded';
    IF current_status <> 'draft' AND uploaded_count <> 3 THEN
        RAISE EXCEPTION 'An evaluation requires three uploaded images before leaving draft' USING ERRCODE = '23514';
    END IF;
    SELECT count(*) INTO result_count FROM public.results WHERE evaluation_id = target;
    IF (current_status = 'completed' AND result_count <> 1)
        OR (current_status <> 'completed' AND result_count <> 0) THEN
        RAISE EXCEPTION 'Evaluation status and result do not match' USING ERRCODE = '23514';
    END IF;
    RETURN NULL;
END;
$$;
CREATE CONSTRAINT TRIGGER evaluations_consistent AFTER INSERT OR UPDATE OR DELETE ON public.evaluations
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION private.check_evaluation();
CREATE CONSTRAINT TRIGGER images_consistent AFTER INSERT OR UPDATE OR DELETE ON public.evaluation_images
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION private.check_evaluation();
CREATE CONSTRAINT TRIGGER results_consistent AFTER INSERT OR UPDATE OR DELETE ON public.results
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION private.check_evaluation();

-- Explicit grants are needed even with RLS; default Supabase grants can be broad.
REVOKE ALL ON public.profiles, public.patients, public.evaluations, public.evaluation_images,
    public.model_versions, public.icdr_grades, public.results FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.profiles, public.patients, public.evaluations, public.evaluation_images,
    public.model_versions, public.icdr_grades, public.results TO authenticated;
GRANT UPDATE (full_name) ON public.profiles TO authenticated;
GRANT INSERT (id, dni, first_names, last_names, birth_date, sex, phone, address, medical_history),
    UPDATE (dni, first_names, last_names, birth_date, sex, phone, address, medical_history)
    ON public.patients TO authenticated;
GRANT INSERT (id, patient_id, eye, observations), UPDATE (eye, observations)
    ON public.evaluations TO authenticated;
GRANT INSERT (evaluation_id, position, sha256, content_type, byte_size, width, height),
    UPDATE (sha256, content_type, byte_size, width, height)
    ON public.evaluation_images TO authenticated;
GRANT ALL ON public.profiles, public.patients, public.evaluations, public.evaluation_images,
    public.model_versions, public.icdr_grades, public.results TO service_role;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evaluation_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.model_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.icdr_grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.results ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_read_self ON public.profiles FOR SELECT TO authenticated
    USING ((SELECT private.is_verified_user()) AND (id = (SELECT auth.uid()) OR (SELECT private.is_admin())));
CREATE POLICY profiles_update_self ON public.profiles FOR UPDATE TO authenticated
    USING ((SELECT private.is_verified_user()) AND id = (SELECT auth.uid()))
    WITH CHECK ((SELECT private.is_verified_user()) AND id = (SELECT auth.uid()));
CREATE POLICY patients_read_owned ON public.patients FOR SELECT TO authenticated
    USING ((SELECT private.is_verified_user()) AND (owner_id = (SELECT auth.uid()) OR (SELECT private.is_admin())));
CREATE POLICY patients_insert_owned ON public.patients FOR INSERT TO authenticated
    WITH CHECK ((SELECT private.is_professional()) AND owner_id = (SELECT auth.uid()));
CREATE POLICY patients_update_owned ON public.patients FOR UPDATE TO authenticated
    USING ((SELECT private.is_professional()) AND owner_id = (SELECT auth.uid()))
    WITH CHECK ((SELECT private.is_professional()) AND owner_id = (SELECT auth.uid()));

CREATE POLICY evaluations_read_owned ON public.evaluations FOR SELECT TO authenticated
    USING ((SELECT private.is_verified_user()) AND EXISTS (
        SELECT 1 FROM public.patients p WHERE p.id = patient_id AND (p.owner_id = (SELECT auth.uid()) OR (SELECT private.is_admin()))
    ));
CREATE POLICY evaluations_insert_owned ON public.evaluations FOR INSERT TO authenticated
    WITH CHECK ((SELECT private.is_professional()) AND professional_id = (SELECT auth.uid()) AND status = 'draft' AND EXISTS (
        SELECT 1 FROM public.patients p WHERE p.id = patient_id AND p.owner_id = (SELECT auth.uid())
    ));
CREATE POLICY evaluations_update_draft ON public.evaluations FOR UPDATE TO authenticated
    USING ((SELECT private.is_professional()) AND status = 'draft' AND EXISTS (
        SELECT 1 FROM public.patients p WHERE p.id = patient_id AND p.owner_id = (SELECT auth.uid())
    ))
    WITH CHECK ((SELECT private.is_professional()) AND status = 'draft' AND EXISTS (
        SELECT 1 FROM public.patients p WHERE p.id = patient_id AND p.owner_id = (SELECT auth.uid())
    ));

CREATE POLICY images_read_owned ON public.evaluation_images FOR SELECT TO authenticated
    USING ((SELECT private.is_verified_user()) AND EXISTS (
        SELECT 1 FROM public.evaluations e WHERE e.id = evaluation_id
    ));
CREATE POLICY images_insert_draft ON public.evaluation_images FOR INSERT TO authenticated
    WITH CHECK ((SELECT private.is_professional()) AND upload_status = 'pending' AND EXISTS (
        SELECT 1 FROM public.evaluations e WHERE e.id = evaluation_id AND e.status = 'draft'
    ));
CREATE POLICY images_update_draft ON public.evaluation_images FOR UPDATE TO authenticated
    USING ((SELECT private.is_professional()) AND upload_status = 'pending' AND EXISTS (
        SELECT 1 FROM public.evaluations e WHERE e.id = evaluation_id AND e.status = 'draft'
    ))
    WITH CHECK ((SELECT private.is_professional()) AND upload_status = 'pending' AND EXISTS (
        SELECT 1 FROM public.evaluations e WHERE e.id = evaluation_id AND e.status = 'draft'
    ));
CREATE POLICY results_read_owned ON public.results FOR SELECT TO authenticated
    USING ((SELECT private.is_verified_user()) AND EXISTS (
        SELECT 1 FROM public.evaluations e WHERE e.id = evaluation_id
    ));
CREATE POLICY models_read_verified ON public.model_versions FOR SELECT TO authenticated
    USING ((SELECT private.is_verified_user()));
CREATE POLICY grades_read_verified ON public.icdr_grades FOR SELECT TO authenticated
    USING ((SELECT private.is_verified_user()));

-- Trigger helpers are not callable as public RPCs.
REVOKE ALL ON FUNCTION private.touch_updated_at(), private.create_profile_for_auth_user(),
    private.lock_evaluation_parent(), private.check_evaluation(), private.enforce_professional_role() FROM PUBLIC, anon, authenticated;
