-- Optional hosted smoke check. Run as project owner in SQL Editor.
-- All synthetic rows, helper functions and audit entries are rolled back.
-- No Auth accounts, emails, image objects or clinical predictions are created.
BEGIN;
CREATE FUNCTION pg_temp.retinazo_assert(ok boolean) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'Retinazo smoke check failed'; END IF; END;
$$;
SELECT set_config('request.jwt.claim.sub',(SELECT p.id::text FROM public.profiles p
    JOIN auth.users u ON u.id=p.id WHERE p.role='admin' AND p.is_active
    AND u.email_confirmed_at IS NOT NULL ORDER BY p.created_at LIMIT 1),true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.retinazo_assert((public.admin_overview()->>'users')::integer>=1);
WITH created AS (
    INSERT INTO public.patients(dni,first_names,last_names,birth_date,sex)
    VALUES('00000000','Prueba aislada Retinazo','Sin datos reales','1980-01-01','female') RETURNING id
) SELECT set_config('retinazo.test_patient',id::text,true) FROM created;
UPDATE public.patients SET phone='999999999' WHERE id=current_setting('retinazo.test_patient')::uuid;
SELECT pg_temp.retinazo_assert((SELECT phone='999999999' FROM public.patients WHERE id=current_setting('retinazo.test_patient')::uuid));
SELECT set_config('retinazo.test_evaluation',gen_random_uuid()::text,true);
SELECT public.save_evaluation_draft(current_setting('retinazo.test_evaluation')::uuid,
    current_setting('retinazo.test_patient')::uuid,'right',NULL,
    (SELECT jsonb_agg(jsonb_build_object('position',n,'sha256',repeat(n::text,64),'content_type','image/png','byte_size',10)) FROM generate_series(1,3)n));
SELECT public.admin_update_evaluation(current_setting('retinazo.test_evaluation')::uuid,'left','Prueba temporal');
SELECT pg_temp.retinazo_assert((SELECT eye='left' AND status='draft' FROM public.evaluations WHERE id=current_setting('retinazo.test_evaluation')::uuid));
SELECT pg_temp.retinazo_assert((SELECT count(*)=3 FROM public.evaluation_images WHERE evaluation_id=current_setting('retinazo.test_evaluation')::uuid));
SELECT pg_temp.retinazo_assert((SELECT count(*)>=2 FROM public.admin_audit_log WHERE target_id=current_setting('retinazo.test_patient')::uuid));
DO $$
BEGIN
    PERFORM public.admin_update_user(auth.uid(),'Admin','professional',true);
    RAISE EXCEPTION 'Self demotion was allowed';
EXCEPTION WHEN check_violation THEN NULL;
END;
$$;
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK;
SELECT NOT EXISTS(SELECT 1 FROM public.patients WHERE first_names='Prueba aislada Retinazo') AS rollback_ok;
