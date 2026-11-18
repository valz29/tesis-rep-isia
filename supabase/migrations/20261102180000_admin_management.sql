-- Administration is a verified, active application role; never a client key.
ALTER TABLE public.profiles ADD COLUMN is_active boolean NOT NULL DEFAULT true;

CREATE OR REPLACE FUNCTION private.is_verified_user() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT EXISTS (SELECT 1 FROM auth.users u JOIN public.profiles p ON p.id=u.id
        WHERE u.id=(SELECT auth.uid()) AND u.email_confirmed_at IS NOT NULL AND p.is_active);
$$;

-- A disabled account can read its own non-clinical profile to display the reason.
DROP POLICY profiles_read_self ON public.profiles;
CREATE POLICY profiles_read_self ON public.profiles FOR SELECT TO authenticated
    USING (id=(SELECT auth.uid()) OR (SELECT private.is_admin()));

-- Administrators may also create clinical records under their own identity.
CREATE OR REPLACE FUNCTION private.enforce_professional_role() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE target uuid;
BEGIN
    IF TG_TABLE_NAME = 'profiles' THEN RETURN NEW; END IF;
    IF TG_TABLE_NAME = 'patients' THEN target := NEW.owner_id;
    ELSE target := NEW.professional_id; END IF;
    PERFORM id FROM public.profiles WHERE id=target AND role IN ('professional','admin') FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Account not available' USING ERRCODE='23514'; END IF;
    RETURN NEW;
END;
$$;

CREATE POLICY patients_admin_insert ON public.patients FOR INSERT TO authenticated
    WITH CHECK ((SELECT private.is_admin()));
CREATE POLICY patients_admin_update ON public.patients FOR UPDATE TO authenticated
    USING ((SELECT private.is_admin())) WITH CHECK ((SELECT private.is_admin()));
CREATE POLICY evaluations_admin_insert ON public.evaluations FOR INSERT TO authenticated
    WITH CHECK ((SELECT private.is_admin()) AND professional_id=(SELECT auth.uid()) AND status='draft');
CREATE POLICY evaluations_admin_update ON public.evaluations FOR UPDATE TO authenticated
    USING ((SELECT private.is_admin()) AND status='draft') WITH CHECK ((SELECT private.is_admin()) AND status='draft');
CREATE POLICY images_admin_insert ON public.evaluation_images FOR INSERT TO authenticated
    WITH CHECK ((SELECT private.is_admin()) AND upload_status='pending' AND EXISTS (
        SELECT 1 FROM public.evaluations WHERE id=evaluation_id AND status='draft'));
CREATE POLICY images_admin_update ON public.evaluation_images FOR UPDATE TO authenticated
    USING ((SELECT private.is_admin()) AND upload_status='pending' AND EXISTS (
        SELECT 1 FROM public.evaluations WHERE id=evaluation_id AND status='draft'))
    WITH CHECK ((SELECT private.is_admin()) AND upload_status='pending' AND EXISTS (
        SELECT 1 FROM public.evaluations WHERE id=evaluation_id AND status='draft'));

CREATE TABLE public.admin_audit_log (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_id uuid NOT NULL,
    action text NOT NULL,
    target_id uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_audit_log FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.admin_audit_log TO authenticated;
CREATE POLICY audit_admin_read ON public.admin_audit_log FOR SELECT TO authenticated
    USING ((SELECT private.is_admin()));
CREATE INDEX admin_audit_date_idx ON public.admin_audit_log(created_at DESC);

CREATE FUNCTION private.audit_admin_clinical_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
    IF (SELECT private.is_admin()) THEN
        INSERT INTO public.admin_audit_log(actor_id,action,target_id)
            VALUES (auth.uid(),TG_TABLE_NAME||'.'||lower(TG_OP),NEW.id);
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER patients_admin_audit AFTER INSERT OR UPDATE ON public.patients
    FOR EACH ROW EXECUTE FUNCTION private.audit_admin_clinical_change();
CREATE TRIGGER evaluations_admin_audit AFTER INSERT OR UPDATE ON public.evaluations
    FOR EACH ROW EXECUTE FUNCTION private.audit_admin_clinical_change();
REVOKE ALL ON FUNCTION private.audit_admin_clinical_change() FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.admin_list_users(query_input text DEFAULT '',offset_input integer DEFAULT 0)
RETURNS TABLE(id uuid,full_name text,email text,role text,is_active boolean,
    email_confirmed_at timestamptz,created_at timestamptz,last_sign_in_at timestamptz,patient_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
    IF NOT (SELECT private.is_admin()) THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501'; END IF;
    RETURN QUERY SELECT p.id,p.full_name,u.email::text,p.role,p.is_active,u.email_confirmed_at,
        u.created_at,u.last_sign_in_at,(SELECT count(*) FROM public.patients x WHERE x.owner_id=p.id)
        FROM public.profiles p JOIN auth.users u ON u.id=p.id
        WHERE coalesce(p.full_name,'') ILIKE '%'||left(coalesce(query_input,''),150)||'%'
           OR u.email ILIKE '%'||left(coalesce(query_input,''),150)||'%'
        ORDER BY u.created_at DESC,p.id LIMIT 50 OFFSET greatest(coalesce(offset_input,0),0);
END;
$$;

CREATE FUNCTION public.admin_overview() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
    IF NOT (SELECT private.is_admin()) THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501'; END IF;
    RETURN jsonb_build_object('users',(SELECT count(*) FROM public.profiles),
        'unconfirmed',(SELECT count(*) FROM auth.users WHERE email_confirmed_at IS NULL),
        'inactive',(SELECT count(*) FROM public.profiles WHERE NOT is_active),
        'patients',(SELECT count(*) FROM public.patients),
        'evaluations',(SELECT count(*) FROM public.evaluations),
        'drafts',(SELECT count(*) FROM public.evaluations WHERE status='draft'));
END;
$$;

CREATE FUNCTION public.admin_update_user(user_id_input uuid,name_input text,role_input text,active_input boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE current_profile public.profiles%ROWTYPE;
BEGIN
    -- Serialize role/activation changes so concurrent requests cannot remove every admin.
    PERFORM pg_advisory_xact_lock(73071129);
    IF NOT (SELECT private.is_admin()) THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501'; END IF;
    IF name_input IS NULL OR btrim(name_input)='' OR length(name_input)>150 OR role_input NOT IN ('professional','admin') OR role_input IS NULL OR active_input IS NULL THEN
        RAISE EXCEPTION 'Invalid account data' USING ERRCODE='23514';
    END IF;
    SELECT * INTO current_profile FROM public.profiles WHERE id=user_id_input FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Account not available' USING ERRCODE='23514'; END IF;
    IF user_id_input=auth.uid() AND (role_input<>'admin' OR NOT active_input) THEN
        RAISE EXCEPTION 'Cannot disable your own administrator' USING ERRCODE='23514';
    END IF;
    IF role_input='admin' AND NOT EXISTS(SELECT 1 FROM auth.users WHERE id=user_id_input AND email_confirmed_at IS NOT NULL) THEN
        RAISE EXCEPTION 'Confirm email before granting admin' USING ERRCODE='23514';
    END IF;
    IF current_profile.role='admin' AND current_profile.is_active AND (role_input<>'admin' OR NOT active_input) AND
        NOT EXISTS(SELECT 1 FROM public.profiles p JOIN auth.users u ON u.id=p.id
            WHERE p.id<>user_id_input AND p.role='admin' AND p.is_active AND u.email_confirmed_at IS NOT NULL) THEN
        RAISE EXCEPTION 'At least one active verified admin required' USING ERRCODE='23514';
    END IF;
    UPDATE public.profiles SET full_name=btrim(name_input),role=role_input,is_active=active_input WHERE id=user_id_input;
    INSERT INTO public.admin_audit_log(actor_id,action,target_id) VALUES(auth.uid(),'users.update',user_id_input);
END;
$$;

CREATE FUNCTION public.admin_reassign_patient(patient_id_input uuid,owner_id_input uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
    IF NOT (SELECT private.is_admin()) THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501'; END IF;
    PERFORM p.id FROM public.profiles p JOIN auth.users u ON u.id=p.id
        WHERE p.id=owner_id_input AND p.is_active AND u.email_confirmed_at IS NOT NULL FOR SHARE OF p;
    IF NOT FOUND THEN RAISE EXCEPTION 'Choose an active verified account' USING ERRCODE='23514'; END IF;
    UPDATE public.patients SET owner_id=owner_id_input WHERE id=patient_id_input;
    IF NOT FOUND THEN RAISE EXCEPTION 'Patient not available' USING ERRCODE='23514'; END IF;
    -- Evaluation author IDs remain unchanged: responsibility is not authorship.
END;
$$;

CREATE FUNCTION public.admin_update_evaluation(evaluation_id_input uuid,eye_input text,observations_input text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE record public.evaluations%ROWTYPE;
BEGIN
    IF NOT (SELECT private.is_admin()) THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501'; END IF;
    SELECT * INTO record FROM public.evaluations WHERE id=evaluation_id_input FOR UPDATE;
    IF NOT FOUND OR eye_input IS NULL OR eye_input NOT IN ('right','left') THEN RAISE EXCEPTION 'Invalid evaluation' USING ERRCODE='23514'; END IF;
    IF record.status<>'draft' AND record.eye<>eye_input THEN
        RAISE EXCEPTION 'Only drafts allow an eye correction' USING ERRCODE='23514';
    END IF;
    UPDATE public.evaluations SET eye=eye_input,observations=nullif(btrim(observations_input),'') WHERE id=evaluation_id_input;
END;
$$;

CREATE FUNCTION public.admin_delete_empty_user(user_id_input uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(73071129);
    IF NOT (SELECT private.is_admin()) THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501'; END IF;
    IF user_id_input=auth.uid() THEN RAISE EXCEPTION 'Cannot delete your own account' USING ERRCODE='23514'; END IF;
    PERFORM id FROM public.profiles WHERE id=user_id_input FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Account not available' USING ERRCODE='23514'; END IF;
    IF EXISTS(SELECT 1 FROM public.patients WHERE owner_id=user_id_input) OR
        EXISTS(SELECT 1 FROM public.evaluations WHERE professional_id=user_id_input) THEN
        RAISE EXCEPTION 'Account has clinical records; deactivate it instead' USING ERRCODE='23514';
    END IF;
    DELETE FROM auth.users WHERE id=user_id_input;
    INSERT INTO public.admin_audit_log(actor_id,action,target_id) VALUES(auth.uid(),'users.delete',user_id_input);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_users(text,integer),public.admin_overview(),
    public.admin_update_user(uuid,text,text,boolean),public.admin_reassign_patient(uuid,uuid),
    public.admin_update_evaluation(uuid,text,text),public.admin_delete_empty_user(uuid)
    FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_users(text,integer),public.admin_overview(),
    public.admin_update_user(uuid,text,text,boolean),public.admin_reassign_patient(uuid,uuid),
    public.admin_update_evaluation(uuid,text,text),public.admin_delete_empty_user(uuid) TO authenticated;
