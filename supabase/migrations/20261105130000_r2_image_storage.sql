-- R2 files are authorized by FastAPI; SQL keeps the verified object references.
ALTER TABLE public.evaluation_images ADD COLUMN storage_provider text
    CHECK (storage_provider IS NULL OR storage_provider='cloudflare_r2');
-- Existing populated references must be reviewed before applying this migration.
ALTER TABLE public.evaluation_images ADD CONSTRAINT image_provider_reference
    CHECK ((storage_provider IS NULL)=(storage_bucket IS NULL));

CREATE FUNCTION public.finish_r2_upload(actor_id_input uuid,evaluation_id_input uuid,images_input jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor_role text; patient_owner uuid; record public.evaluations%ROWTYPE;
BEGIN
    -- This function is executable ONLY by a trusted backend service credential.
    -- Never grant it to authenticated/anon, even if they supply their own actor ID.
    SELECT p.role INTO actor_role FROM public.profiles p JOIN auth.users u ON u.id=p.id
        WHERE p.id=actor_id_input AND p.is_active AND u.email_confirmed_at IS NOT NULL FOR SHARE OF p;
    IF actor_role IS NULL THEN RAISE EXCEPTION 'Active verified account required' USING ERRCODE='42501'; END IF;
    SELECT * INTO record FROM public.evaluations WHERE id=evaluation_id_input FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Evaluation not available' USING ERRCODE='42501'; END IF;
    SELECT owner_id INTO patient_owner FROM public.patients WHERE id=record.patient_id FOR SHARE;
    IF actor_role<>'admin' AND patient_owner<>actor_id_input THEN
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
