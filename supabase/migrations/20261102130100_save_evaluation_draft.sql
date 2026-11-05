-- The request is atomic: all three metadata rows are saved, or none are.
-- SECURITY INVOKER preserves RLS, column grants and the caller's identity.
CREATE FUNCTION public.save_evaluation_draft(
    evaluation_id_input uuid,
    patient_id_input uuid,
    eye_input text,
    observations_input text,
    images_input jsonb
) RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE existing public.evaluations%ROWTYPE; inserted_id uuid;
BEGIN
    IF jsonb_typeof(images_input) IS DISTINCT FROM 'array' OR jsonb_array_length(images_input) <> 3 THEN
        RAISE EXCEPTION 'Exactly three images are required' USING ERRCODE = '23514';
    END IF;
    INSERT INTO public.evaluations(id, patient_id, eye, observations)
        VALUES (evaluation_id_input, patient_id_input, eye_input, observations_input)
        ON CONFLICT (id) DO NOTHING RETURNING id INTO inserted_id;
    IF inserted_id IS NULL THEN
        SELECT * INTO existing FROM public.evaluations WHERE id = evaluation_id_input;
        IF NOT FOUND OR existing.professional_id <> (SELECT auth.uid()) OR
            existing.patient_id <> patient_id_input OR existing.eye <> eye_input THEN
            RAISE EXCEPTION 'Evaluation is not available' USING ERRCODE = '42501';
        END IF;
        RETURN existing.id;
    END IF;
    INSERT INTO public.evaluation_images(evaluation_id, position, sha256, content_type, byte_size)
        SELECT evaluation_id_input, (item->>'position')::smallint, item->>'sha256',
            item->>'content_type', (item->>'byte_size')::bigint
        FROM jsonb_array_elements(images_input) AS item;
    RETURN inserted_id;
END;
$$;
REVOKE ALL ON FUNCTION public.save_evaluation_draft(uuid, uuid, text, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_evaluation_draft(uuid, uuid, text, text, jsonb) TO authenticated;
