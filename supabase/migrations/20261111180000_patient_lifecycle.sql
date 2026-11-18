-- Administration manages records; only professionals own patients and author new evaluations.
ALTER TABLE public.patients
    ADD COLUMN is_active boolean NOT NULL DEFAULT true,
    ADD COLUMN deactivated_at timestamptz,
    ADD COLUMN deactivated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN deactivation_reason text,
    ALTER COLUMN owner_id DROP NOT NULL,
    ADD CONSTRAINT patient_lifecycle CHECK (
        (is_active AND owner_id IS NOT NULL AND deactivated_at IS NULL
            AND deactivated_by IS NULL AND deactivation_reason IS NULL)
        OR (NOT is_active AND deactivated_at IS NOT NULL
            AND nullif(btrim(deactivation_reason),'') IS NOT NULL)
    );

CREATE OR REPLACE FUNCTION private.enforce_professional_role() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE target uuid;
BEGIN
    IF auth.uid() IS NOT NULL AND NOT (SELECT private.is_verified_user()) THEN
        RAISE EXCEPTION 'Active verified account required' USING ERRCODE='42501';
    END IF;
    IF TG_TABLE_NAME='profiles' THEN
        IF NEW.role='admin' AND OLD.role IS DISTINCT FROM NEW.role AND
            EXISTS(SELECT 1 FROM public.patients WHERE owner_id=OLD.id) THEN
            RAISE EXCEPTION 'Reassign patients before granting administrator role' USING ERRCODE='23514';
        END IF;
        RETURN NEW;
    END IF;
    IF TG_TABLE_NAME='patients' THEN
        target:=NEW.owner_id;
        IF target IS NULL AND NOT NEW.is_active THEN RETURN NEW; END IF;
        IF TG_OP='UPDATE' AND NEW.owner_id IS NOT DISTINCT FROM OLD.owner_id THEN
            PERFORM id FROM public.profiles WHERE id=target AND role='professional' FOR SHARE;
            IF NOT FOUND THEN RAISE EXCEPTION 'Active verified professional required' USING ERRCODE='23514'; END IF;
            RETURN NEW;
        END IF;
    ELSE
        target:=NEW.professional_id;
        PERFORM id FROM public.patients WHERE id=NEW.patient_id AND is_active FOR SHARE;
        IF NOT FOUND THEN
            IF NOT EXISTS(SELECT 1 FROM public.patients WHERE id=NEW.patient_id) THEN
                RAISE EXCEPTION 'Patient not available' USING ERRCODE='23503';
            END IF;
            RAISE EXCEPTION 'Active patient required' USING ERRCODE='23514';
        END IF;
    END IF;
    PERFORM p.id FROM public.profiles p JOIN auth.users u ON u.id=p.id
        WHERE p.id=target AND p.role='professional' AND p.is_active
            AND u.email_confirmed_at IS NOT NULL FOR SHARE OF p;
    IF NOT FOUND THEN RAISE EXCEPTION 'Active verified professional required' USING ERRCODE='23514'; END IF;
    RETURN NEW;
END;
$$;

-- Existing legacy records are preserved until the owner chooses archival,
-- reassignment or an explicit one-off cleanup. Deactivation below also removes
-- legacy administrator ownership without assigning the record to another user.

GRANT INSERT(owner_id) ON public.patients TO authenticated;
DROP POLICY patients_update_owned ON public.patients;
CREATE POLICY patients_update_owned ON public.patients FOR UPDATE TO authenticated
    USING ((SELECT private.is_professional()) AND is_active AND owner_id=(SELECT auth.uid()))
    WITH CHECK ((SELECT private.is_professional()) AND is_active AND owner_id=(SELECT auth.uid()));

-- Administrators retain read/correction rights, without clinical authoring rights.
DROP POLICY evaluations_admin_insert ON public.evaluations;
DROP POLICY images_admin_insert ON public.evaluation_images;
DROP POLICY images_admin_update ON public.evaluation_images;

CREATE FUNCTION private.guard_patient_activity() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
    IF TG_TABLE_NAME='patients' THEN
        IF NEW.is_active AND (NOT OLD.is_active) THEN
            PERFORM p.id FROM public.profiles p JOIN auth.users u ON u.id=p.id
                WHERE p.id=NEW.owner_id AND p.role='professional' AND p.is_active
                    AND u.email_confirmed_at IS NOT NULL FOR SHARE OF p;
            IF NOT FOUND THEN RAISE EXCEPTION 'Assign an active verified professional before reactivation' USING ERRCODE='23514'; END IF;
        END IF;
    ELSE
        PERFORM p.id FROM public.patients p JOIN public.evaluations e ON e.patient_id=p.id
            WHERE e.id=NEW.evaluation_id AND p.is_active FOR SHARE OF p;
        IF NOT FOUND THEN RAISE EXCEPTION 'Active patient required' USING ERRCODE='23514'; END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER patient_reactivation_guard BEFORE UPDATE OF is_active ON public.patients
    FOR EACH ROW EXECUTE FUNCTION private.guard_patient_activity();
CREATE TRIGGER image_patient_activity_guard BEFORE INSERT OR UPDATE ON public.evaluation_images
    FOR EACH ROW EXECUTE FUNCTION private.guard_patient_activity();
REVOKE ALL ON FUNCTION private.guard_patient_activity() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.admin_reassign_patient(patient_id_input uuid,owner_id_input uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
    IF NOT (SELECT private.is_admin()) THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501'; END IF;
    PERFORM p.id FROM public.profiles p JOIN auth.users u ON u.id=p.id
        WHERE p.id=owner_id_input AND p.role='professional' AND p.is_active
            AND u.email_confirmed_at IS NOT NULL FOR SHARE OF p;
    IF NOT FOUND THEN RAISE EXCEPTION 'Choose an active verified professional' USING ERRCODE='23514'; END IF;
    UPDATE public.patients SET owner_id=owner_id_input WHERE id=patient_id_input;
    IF NOT FOUND THEN RAISE EXCEPTION 'Patient not available' USING ERRCODE='23514'; END IF;
END;
$$;

CREATE FUNCTION public.admin_set_patient_active(patient_id_input uuid,active_input boolean,reason_input text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
    IF NOT (SELECT private.is_admin()) THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501'; END IF;
    IF active_input IS NULL OR (NOT active_input AND (nullif(btrim(reason_input),'') IS NULL OR length(reason_input)>500)) THEN
        RAISE EXCEPTION 'A deactivation reason is required' USING ERRCODE='23514';
    END IF;
    UPDATE public.patients SET is_active=active_input,
        owner_id=CASE WHEN NOT active_input AND owner_id IN
            (SELECT id FROM public.profiles WHERE role='admin') THEN NULL ELSE owner_id END,
        deactivated_at=CASE WHEN active_input THEN NULL ELSE now() END,
        deactivated_by=CASE WHEN active_input THEN NULL ELSE auth.uid() END,
        deactivation_reason=CASE WHEN active_input THEN NULL ELSE btrim(reason_input) END
        WHERE id=patient_id_input;
    IF NOT FOUND THEN RAISE EXCEPTION 'Patient not available' USING ERRCODE='23514'; END IF;
    INSERT INTO public.admin_audit_log(actor_id,action,target_id)
        VALUES(auth.uid(),CASE WHEN active_input THEN 'patients.reactivate' ELSE 'patients.deactivate' END,patient_id_input);
END;
$$;

CREATE FUNCTION public.admin_eligible_professionals(query_input text DEFAULT '')
RETURNS TABLE(id uuid,full_name text,email text,role text,is_active boolean,email_confirmed_at timestamptz,
    created_at timestamptz,last_sign_in_at timestamptz,patient_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
    IF NOT (SELECT private.is_admin()) THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501'; END IF;
    RETURN QUERY SELECT p.id,p.full_name,u.email::text,p.role,p.is_active,u.email_confirmed_at,
        u.created_at,u.last_sign_in_at,(SELECT count(*) FROM public.patients x WHERE x.owner_id=p.id)
        FROM public.profiles p JOIN auth.users u ON u.id=p.id
        WHERE p.role='professional' AND p.is_active AND u.email_confirmed_at IS NOT NULL
            AND (coalesce(p.full_name,'') ILIKE '%'||left(coalesce(query_input,''),150)||'%'
                OR u.email ILIKE '%'||left(coalesce(query_input,''),150)||'%')
        ORDER BY p.full_name NULLS LAST,p.id LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_set_patient_active(uuid,boolean,text),public.admin_eligible_professionals(text)
    FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_patient_active(uuid,boolean,text),public.admin_eligible_professionals(text)
    TO authenticated;

-- Finalization rechecks activity even if permissions changed during upload.
CREATE OR REPLACE FUNCTION public.finish_r2_upload(actor_id_input uuid,evaluation_id_input uuid,images_input jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor_role text; patient_owner uuid; record public.evaluations%ROWTYPE;
BEGIN
    -- This function is executable ONLY by a trusted backend service credential.
    -- Never grant it to authenticated/anon, even if they supply their own actor ID.
    SELECT p.role INTO actor_role FROM public.profiles p JOIN auth.users u ON u.id=p.id
        WHERE p.id=actor_id_input AND p.is_active AND u.email_confirmed_at IS NOT NULL FOR SHARE OF p;
    IF actor_role IS DISTINCT FROM 'professional' THEN RAISE EXCEPTION 'Active verified account required' USING ERRCODE='42501'; END IF;
    SELECT * INTO record FROM public.evaluations WHERE id=evaluation_id_input FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Evaluation not available' USING ERRCODE='42501'; END IF;
    SELECT owner_id INTO patient_owner FROM public.patients WHERE id=record.patient_id AND is_active FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Active patient required' USING ERRCODE='23514'; END IF;
    IF patient_owner<>actor_id_input THEN
        RAISE EXCEPTION 'Evaluation not available' USING ERRCODE='42501';
    END IF;
    IF jsonb_typeof(images_input) IS DISTINCT FROM 'array' OR jsonb_array_length(images_input)<>3 THEN
        RAISE EXCEPTION 'Three verified objects required' USING ERRCODE='23514';
    END IF;
    IF (SELECT count(DISTINCT x.position) FROM jsonb_to_recordset(images_input) AS x(position smallint))<>3 OR
       (SELECT count(*) FROM public.evaluation_images WHERE evaluation_id=evaluation_id_input)<>3 OR
       (SELECT count(*) FROM public.evaluation_images m JOIN jsonb_to_recordset(images_input) AS x(
            position smallint,sha256 text,content_type text,byte_size bigint,storage_bucket text,object_key text,width integer,height integer
        ) ON m.position=x.position AND m.sha256=x.sha256 AND m.content_type=x.content_type AND m.byte_size=x.byte_size
        WHERE m.evaluation_id=evaluation_id_input AND x.content_type IN ('image/jpeg','image/png')
            AND x.width>0 AND x.height>0 AND x.width::bigint*x.height<=40000000
            AND x.storage_bucket ~ '^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$'
            AND x.object_key='evaluations/'||evaluation_id_input::text||'/'||m.position::text||'-'||m.sha256||
                CASE x.content_type WHEN 'image/jpeg' THEN '.jpg' ELSE '.png' END)<>3 THEN
        RAISE EXCEPTION 'Objects do not match current image metadata' USING ERRCODE='23514';
    END IF;
    IF record.status<>'draft' THEN
        IF (SELECT count(*) FROM public.evaluation_images m JOIN jsonb_to_recordset(images_input) AS x(
                position smallint,storage_bucket text,object_key text
            ) ON m.position=x.position AND m.storage_bucket=x.storage_bucket AND m.object_key=x.object_key
            WHERE m.evaluation_id=evaluation_id_input AND m.upload_status='uploaded' AND m.storage_provider='cloudflare_r2')=3 THEN RETURN; END IF;
        RAISE EXCEPTION 'Evaluation is no longer a draft' USING ERRCODE='23514';
    END IF;
    UPDATE public.evaluation_images m SET storage_provider='cloudflare_r2',upload_status='uploaded',
        storage_bucket=x.storage_bucket,object_key=x.object_key,uploaded_at=now(),width=x.width,height=x.height
        FROM jsonb_to_recordset(images_input) AS x(position smallint,storage_bucket text,object_key text,width integer,height integer)
        WHERE m.evaluation_id=evaluation_id_input AND m.position=x.position;
    UPDATE public.evaluations SET status='pending_analysis' WHERE id=evaluation_id_input;
    IF actor_role='admin' THEN
        INSERT INTO public.admin_audit_log(actor_id,action,target_id) VALUES(actor_id_input,'images.upload',evaluation_id_input);
    END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.finish_r2_upload(uuid,uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.finish_r2_upload(uuid,uuid,jsonb) TO service_role;
