#!/usr/bin/env python3
"""Validate the migration and RLS against disposable PostgreSQL, using Docker.

No host ports, persistent volumes, real users, credentials, or clinical images.
The Auth stub tests database integration only; it does not implement Supabase Auth.
"""
from pathlib import Path
import os
import secrets
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
IMAGE = "postgres:16-alpine@sha256:0cefaabd882e42bcb2a2f3dc56d3ce4770560ba62fd7f197f1a2e008fd5731ab"
U1 = "10000000-0000-0000-0000-000000000001"
U2 = "10000000-0000-0000-0000-000000000002"
U3 = "10000000-0000-0000-0000-000000000003"
ADMIN = "10000000-0000-0000-0000-000000000004"
P1 = "20000000-0000-0000-0000-000000000001"
P2 = "20000000-0000-0000-0000-000000000002"
E1 = "30000000-0000-0000-0000-000000000001"
E2 = "30000000-0000-0000-0000-000000000002"
MODEL = "40000000-0000-0000-0000-000000000001"
CONTAINER = "retinazo-schema-test-" + secrets.token_hex(4)


def sql(content):
    return subprocess.run(
        ["docker", "exec", "-i", CONTAINER, "psql", "-X", "-q", "-U", "postgres",
         "-d", "retinazo_test", "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=sqlstate"],
        input=content, text=True, capture_output=True, timeout=30,
    )


def execute(content):
    result = sql(content)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result.stdout


def as_user(user=U1):
    return f"SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub = '{user}';"


def three_images():
    return f"""
        INSERT INTO public.evaluation_images
            (evaluation_id, position, sha256, content_type, byte_size,
             storage_provider, storage_bucket, object_key, upload_status, uploaded_at)
        SELECT '{E1}', n, repeat(n::text, 64), 'image/png', 10,
            'cloudflare_r2', 'synthetic-test-bucket', 'synthetic/' || n, 'uploaded', now()
        FROM generate_series(1, 3) n;
    """


def complete_result():
    return f"""
        INSERT INTO public.model_versions(id, model_name, version)
            VALUES ('{MODEL}', 'synthetic-test-only', 'test');
        INSERT INTO public.results(evaluation_id, model_version_id, icdr_grade, confidence)
            VALUES ('{E1}', '{MODEL}', 0, 0.8);
        UPDATE public.evaluations SET status = 'completed' WHERE id = '{E1}';
    """


class SchemaTests(unittest.TestCase):
    def check_sql(self, body, error=None):
        result = sql("BEGIN;\n" + body + "\nSET CONSTRAINTS ALL IMMEDIATE;\nROLLBACK;")
        if error:
            self.assertNotEqual(result.returncode, 0, "Invalid data was accepted")
            self.assertIn(error, result.stderr, result.stderr)
        else:
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_profile_trigger_and_backfill(self):
        self.check_sql("SELECT public.test_assert((SELECT count(*) = 4 FROM public.profiles));")

    def test_catalog_and_no_invented_predictions(self):
        self.check_sql("""
            SELECT public.test_assert((SELECT count(*) = 5 FROM public.icdr_grades));
            SELECT public.test_assert((SELECT count(*) = 0 FROM public.results));
            SELECT public.test_assert((SELECT count(*) = 0 FROM public.model_versions));
        """)

    def test_verified_owner_reads_and_edits_own_patient(self):
        self.check_sql(as_user() + f"""
            SELECT public.test_assert((SELECT count(*) = 1 FROM public.patients));
            UPDATE public.patients SET first_names = 'Edited' WHERE id = '{P1}';
            SELECT public.test_assert((SELECT first_names = 'Edited' FROM public.patients WHERE id = '{P1}'));
        """)

    def test_other_owners_data_stays_invisible_and_unmodified(self):
        self.check_sql(as_user() + f"""
            SELECT public.test_assert((SELECT count(*) = 0 FROM public.patients WHERE id = '{P2}'));
            UPDATE public.patients SET first_names = 'Unauthorized' WHERE id = '{P2}';
            RESET ROLE;
            SELECT public.test_assert((SELECT first_names = 'Second' FROM public.patients WHERE id = '{P2}'));
        """)

    def test_unconfirmed_account_cannot_create_patient(self):
        self.check_sql(as_user(U3) + """
            INSERT INTO public.patients(dni, first_names, last_names, birth_date, sex)
                VALUES ('98765432', 'Test', 'Test', '1980-01-01', 'female');
        """, "42501")

    def test_unconfirmed_account_cannot_read_records_or_catalog(self):
        self.check_sql(as_user(U3) + """
            SELECT public.test_assert((SELECT count(*) = 0 FROM public.patients));
            SELECT public.test_assert((SELECT count(*) = 0 FROM public.icdr_grades));
        """)

    def test_anonymous_has_no_table_access(self):
        self.check_sql("SET LOCAL ROLE anon; SELECT * FROM public.patients;", "42501")

    def test_verified_owner_can_create_patient_with_server_owner(self):
        self.check_sql(as_user() + f"""
            INSERT INTO public.patients(dni, first_names, last_names, birth_date, sex)
                VALUES ('98765432', 'New', 'Patient', '1980-01-01', 'female');
            SELECT public.test_assert((SELECT owner_id = '{U1}' FROM public.patients WHERE dni = '98765432'));
        """)

    def test_owner_cannot_be_forged(self):
        self.check_sql(as_user() + f"UPDATE public.patients SET owner_id = '{U2}' WHERE id = '{P1}';", "42501")

    def test_duplicate_dni_within_owner_is_rejected(self):
        self.check_sql(as_user() + """
            INSERT INTO public.patients(dni, first_names, last_names, birth_date, sex)
                VALUES ('12345678', 'Duplicate', 'Patient', '1980-01-01', 'male');
        """, "23505")

    def test_invalid_dni_and_future_birth_are_rejected(self):
        for dni, birth in [('123', '1980-01-01'), ('87654321', '2999-01-01')]:
            with self.subTest(dni=dni):
                self.check_sql(as_user() + f"""
                    INSERT INTO public.patients(dni, first_names, last_names, birth_date, sex)
                        VALUES ('{dni}', 'Invalid', 'Patient', '{birth}', 'female');
                """, "23514")

    def test_patient_can_have_evaluations_of_both_eyes(self):
        self.check_sql(as_user() + f"""
            INSERT INTO public.evaluations(patient_id, eye) VALUES ('{P1}', 'left');
            SELECT public.test_assert((SELECT count(DISTINCT eye) = 2 FROM public.evaluations WHERE patient_id = '{P1}'));
        """)

    def test_evaluation_cannot_reference_other_owners_patient(self):
        self.check_sql(as_user() + f"INSERT INTO public.evaluations(patient_id, eye) VALUES ('{P2}', 'left');", "42501")

    def test_image_cannot_reference_other_owners_evaluation(self):
        self.check_sql(as_user() + f"""
            INSERT INTO public.evaluation_images(evaluation_id, position, sha256, content_type, byte_size)
                VALUES ('{E2}', 1, repeat('a', 64), 'image/png', 10);
        """, "42501")

    def test_admin_reads_all_image_metadata_and_results(self):
        self.check_sql(three_images() + complete_result() + as_user(ADMIN) + """
            SELECT public.test_assert((SELECT count(*) = 3 FROM public.evaluation_images));
            SELECT public.test_assert((SELECT count(*) = 1 FROM public.results));
        """)
        self.check_sql(three_images() + complete_result() + as_user(U2) + """
            SELECT public.test_assert((SELECT count(*) = 0 FROM public.evaluation_images));
            SELECT public.test_assert((SELECT count(*) = 0 FROM public.results));
        """)

    def test_client_cannot_truncate_tables(self):
        self.check_sql(as_user() + "TRUNCATE public.patients CASCADE;", "42501")

    def test_broken_foreign_key_is_rejected(self):
        self.check_sql(f"INSERT INTO public.evaluations(patient_id, professional_id, eye) VALUES (gen_random_uuid(), '{U1}', 'right');", "23503")

    def test_duplicate_image_or_fourth_slot_is_rejected(self):
        for position in [2, 4]:
            with self.subTest(position=position):
                self.check_sql(as_user() + f"""
                    INSERT INTO public.evaluation_images(evaluation_id, position, sha256, content_type, byte_size)
                        VALUES ('{E1}', 1, repeat('a', 64), 'image/png', 10);
                    INSERT INTO public.evaluation_images(evaluation_id, position, sha256, content_type, byte_size)
                        VALUES ('{E1}', {position}, repeat('a', 64), 'image/png', 10);
                """, "23505" if position == 2 else "23514")

    def test_client_cannot_claim_upload_or_inference(self):
        self.check_sql(as_user() + f"UPDATE public.evaluations SET status = 'completed' WHERE id = '{E1}';", "42501")
        self.check_sql(three_images() + as_user() + f"UPDATE public.evaluation_images SET upload_status = 'uploaded' WHERE evaluation_id = '{E1}';", "42501")
        self.check_sql(as_user() + f"INSERT INTO public.results(evaluation_id, model_version_id, icdr_grade) VALUES ('{E1}', '{MODEL}', 2);", "42501")

    def test_three_uploads_required_before_analysis(self):
        self.check_sql(f"UPDATE public.evaluations SET status = 'pending_analysis' WHERE id = '{E1}';", "23514")
        self.check_sql(three_images() + f"UPDATE public.evaluations SET status = 'pending_analysis' WHERE id = '{E1}';")

    def test_completed_requires_result_and_result_requires_completed(self):
        self.check_sql(three_images() + f"UPDATE public.evaluations SET status = 'completed' WHERE id = '{E1}';", "23514")
        self.check_sql(three_images() + complete_result() + f"UPDATE public.evaluations SET status = 'pending_analysis' WHERE id = '{E1}';", "23514")
        self.check_sql(three_images() + complete_result())

    def test_ungradable_has_reason_and_no_grade(self):
        self.check_sql(three_images() + f"UPDATE public.evaluations SET status = 'not_gradable' WHERE id = '{E1}';", "23514")
        self.check_sql(three_images() + f"""
            UPDATE public.evaluations SET status = 'not_gradable', not_gradable_reason = 'Synthetic quality test' WHERE id = '{E1}';
            SELECT public.test_assert((SELECT count(*) = 0 FROM public.results WHERE evaluation_id = '{E1}'));
        """)

    def test_invalid_grade_and_confidence_are_rejected(self):
        for clause, error in [("icdr_grade = 5", "23503"), ("confidence = 1.1", "23514"), ("confidence = 'NaN'", "23514")]:
            with self.subTest(clause=clause):
                self.check_sql(three_images() + complete_result() + f"UPDATE public.results SET {clause} WHERE evaluation_id = '{E1}';", error)

    def test_finalized_evaluation_cannot_lose_an_image(self):
        self.check_sql(three_images() + complete_result() + f"DELETE FROM public.evaluation_images WHERE evaluation_id = '{E1}' AND position = 3;", "23514")

    def test_admin_can_read_all_patients_and_evaluations(self):
        self.check_sql(as_user(ADMIN) + """
            SELECT public.test_assert((SELECT count(*) = 2 FROM public.patients));
            SELECT public.test_assert((SELECT count(*) = 2 FROM public.evaluations));
            SELECT public.test_assert((SELECT count(*) = 4 FROM public.profiles));
        """)

    def test_admin_can_create_and_edit_clinical_records(self):
        self.check_sql(as_user(ADMIN) + """
            INSERT INTO public.patients(dni, first_names, last_names, birth_date, sex)
                VALUES ('98765432', 'Admin', 'Patient', '1980-01-01', 'female');
        """, '23514')
        self.check_sql(as_user(ADMIN) + f"""
            INSERT INTO public.patients(owner_id,dni,first_names,last_names,birth_date,sex)
                VALUES ('{U1}','98765432','Assigned','Professional','1980-01-01','female');
        """)
        self.check_sql(as_user(ADMIN) + f"""
            UPDATE public.patients SET first_names = 'Admin edit' WHERE id = '{P1}';
            RESET ROLE;
            SELECT public.test_assert((SELECT first_names = 'Admin edit' FROM public.patients WHERE id = '{P1}'));
        """)

    def test_professional_cannot_promote_itself(self):
        self.check_sql(as_user() + f"UPDATE public.profiles SET role = 'admin' WHERE id = '{U1}';", "42501")
        self.check_sql(f"SELECT public.test_assert((SELECT role = 'professional' FROM public.profiles WHERE id = '{U3}'));")

    def test_admin_must_reassign_patients_before_promoting_a_professional(self):
        self.check_sql(as_user(ADMIN) + f"SELECT public.admin_update_user('{U1}','First admin','admin',true);", '23514')
        self.check_sql(as_user(ADMIN) + f"""
            UPDATE public.patients SET dni='87654321' WHERE id='{P1}';
            SELECT public.admin_reassign_patient('{P1}','{U2}');
            SELECT public.admin_update_user('{U1}','First admin','admin',true);
            SELECT public.test_assert((SELECT professional_id='{U1}' FROM public.evaluations WHERE id='{E1}'));
        """)

    def test_admin_users_and_summary_expose_only_safe_fields(self):
        self.check_sql(as_user(ADMIN) + """
            SELECT public.test_assert((SELECT count(*)=4 FROM public.admin_list_users()));
            SELECT public.test_assert((SELECT (public.admin_overview()->>'users')::integer=4));
        """)
        self.check_sql(as_user() + "SELECT * FROM public.admin_list_users();", "42501")
        self.check_sql("SET LOCAL ROLE anon; SELECT public.admin_overview();", "42501")

    def test_admin_cannot_disable_or_demote_itself(self):
        self.check_sql(as_user(ADMIN) + f"SELECT public.admin_update_user('{ADMIN}','Admin','professional',true);", "23514")
        self.check_sql(as_user(ADMIN) + f"SELECT public.admin_update_user('{ADMIN}','Admin','admin',false);", "23514")

    def test_unconfirmed_user_cannot_become_admin(self):
        self.check_sql(as_user(ADMIN) + f"SELECT public.admin_update_user('{U3}','Pending','admin',true);", "23514")

    def test_disabled_user_loses_access_with_existing_claims(self):
        self.check_sql(as_user(ADMIN) + f"""
            SELECT public.admin_update_user('{U1}','Disabled','professional',false);
            RESET ROLE;
        """ + as_user(U1) + """
            SELECT public.test_assert((SELECT count(*)=0 FROM public.patients));
            SELECT public.test_assert((SELECT count(*)=0 FROM public.evaluations));
        """)
        self.check_sql(as_user() + f"UPDATE public.profiles SET is_active=true WHERE id='{U1}';", "42501")

    def test_admin_reassignment_changes_access_but_preserves_authorship(self):
        self.check_sql(as_user(ADMIN) + f"""
            UPDATE public.patients SET dni='87654321' WHERE id='{P1}';
            SELECT public.admin_reassign_patient('{P1}','{U2}');
            SELECT public.test_assert((SELECT professional_id='{U1}' FROM public.evaluations WHERE id='{E1}'));
            RESET ROLE;
        """ + as_user(U1) + f"""
            SELECT public.test_assert((SELECT count(*)=0 FROM public.patients WHERE id='{P1}'));
            RESET ROLE;
        """ + as_user(U2) + "SELECT public.test_assert((SELECT count(*)=2 FROM public.patients));")
        self.check_sql(as_user() + f"SELECT public.admin_reassign_patient('{P1}','{U2}');", "42501")
        self.check_sql(as_user(ADMIN) + f"SELECT public.admin_reassign_patient('{P1}','{U3}');", "23514")

    def test_admin_corrects_evaluations_without_fabricating_predictions(self):
        self.check_sql(as_user(ADMIN) + f"""
            SELECT public.admin_update_evaluation('{E1}','left','Corrected notes');
            SELECT public.test_assert((SELECT eye='left' AND observations='Corrected notes' FROM public.evaluations WHERE id='{E1}'));
            SELECT public.test_assert((SELECT count(*)=0 FROM public.results));
        """)
        self.check_sql(as_user() + f"SELECT public.admin_update_evaluation('{E1}','left','Denied');", "42501")
        self.check_sql(three_images()+complete_result()+as_user(ADMIN)+f"SELECT public.admin_update_evaluation('{E1}','left','Denied');", "23514")

    def test_admin_cannot_bypass_finalized_eye_rule_through_direct_update(self):
        self.check_sql(three_images()+complete_result()+as_user(ADMIN)+f"""
            UPDATE public.evaluations SET eye='left' WHERE id='{E1}';
            SELECT public.test_assert((SELECT eye='right' FROM public.evaluations WHERE id='{E1}'));
        """)

    def test_empty_account_deletion_is_guarded(self):
        self.check_sql(as_user(ADMIN) + f"SELECT public.admin_delete_empty_user('{ADMIN}');", "23514")
        self.check_sql(as_user(ADMIN) + f"SELECT public.admin_delete_empty_user('{U1}');", "23514")
        self.check_sql(as_user() + f"SELECT public.admin_delete_empty_user('{U3}');", "42501")
        self.check_sql(as_user(ADMIN) + f"""
            SELECT public.admin_delete_empty_user('{U3}');
            SELECT public.test_assert((SELECT count(*)=0 FROM public.profiles WHERE id='{U3}'));
        """)

    def test_admin_audit_is_immutable_and_hidden_from_professionals(self):
        self.check_sql(as_user(ADMIN) + f"""
            UPDATE public.patients SET first_names='Corrected' WHERE id='{P1}';
            SELECT public.test_assert((SELECT count(*)=1 FROM public.admin_audit_log WHERE actor_id='{ADMIN}'));
            RESET ROLE;
        """ + as_user() + "SELECT public.test_assert((SELECT count(*)=0 FROM public.admin_audit_log));")
        self.check_sql(as_user(ADMIN) + "DELETE FROM public.admin_audit_log;", "42501")

    def r2_objects(self):
        return f"""(SELECT jsonb_agg(jsonb_build_object('position',n,'sha256',repeat(n::text,64),
            'content_type','image/png','byte_size',10,'width',2,'height',2,
            'storage_bucket','retinazo-test','object_key','evaluations/{E1}/'||n||'-'||repeat(n::text,64)||'.png'))
            FROM generate_series(1,3)n)"""

    def pending_r2_metadata(self):
        return f"""INSERT INTO public.evaluation_images(evaluation_id,position,sha256,content_type,byte_size)
            SELECT '{E1}',n,repeat(n::text,64),'image/png',10 FROM generate_series(1,3)n;"""

    def test_only_server_can_finalize_r2_objects(self):
        call=f"SELECT public.finish_r2_upload('{U1}','{E1}',{self.r2_objects()});"
        self.check_sql(self.pending_r2_metadata()+as_user()+call,'42501')
        self.check_sql(self.pending_r2_metadata()+"SET LOCAL ROLE anon;"+call,'42501')
        self.check_sql(self.pending_r2_metadata()+"SET LOCAL ROLE service_role;"+call+call+f"""
            RESET ROLE;
            SELECT public.test_assert((SELECT status='pending_analysis' FROM public.evaluations WHERE id='{E1}'));
            SELECT public.test_assert((SELECT count(*)=3 FROM public.evaluation_images WHERE evaluation_id='{E1}' AND storage_provider='cloudflare_r2' AND upload_status='uploaded'));
            SELECT public.test_assert((SELECT count(*)=0 FROM public.results));
        """)

    def test_server_must_recheck_owner_and_active_confirmed_actor(self):
        for actor in [U2,U3]:
            self.check_sql(self.pending_r2_metadata()+f"SET LOCAL ROLE service_role;SELECT public.finish_r2_upload('{actor}','{E1}',{self.r2_objects()});",'42501')
        self.check_sql(f"UPDATE public.profiles SET is_active=false WHERE id='{U1}';"+self.pending_r2_metadata()+f"SET LOCAL ROLE service_role;SELECT public.finish_r2_upload('{U1}','{E1}',{self.r2_objects()});",'42501')

    def test_r2_finalize_rejects_unrelated_keys_or_changed_metadata(self):
        for field,value in [('sha256',"to_jsonb(repeat('a',64))"),('object_key',"to_jsonb('another-evaluation/photo.png'::text)"),('position','to_jsonb(2)')]:
            objects=f"jsonb_set({self.r2_objects()},'{{0,{field}}}',{value})"
            self.check_sql(self.pending_r2_metadata()+f"SET LOCAL ROLE service_role;SELECT public.finish_r2_upload('{U1}','{E1}',{objects});",'23514')

    def test_admin_cannot_finalize_clinical_images(self):
        self.check_sql(self.pending_r2_metadata()+f"SET LOCAL ROLE service_role;SELECT public.finish_r2_upload('{ADMIN}','{E1}',{self.r2_objects()});RESET ROLE;"+
            f"SELECT public.test_assert((SELECT count(*)=1 FROM public.admin_audit_log WHERE action='images.upload' AND actor_id='{ADMIN}'));", '42501')

    def test_admin_is_never_an_eligible_patient_owner(self):
        self.check_sql(as_user(ADMIN) + f"SELECT public.admin_reassign_patient('{P1}','{ADMIN}');", '23514')
        self.check_sql(as_user(ADMIN) + """
            SELECT public.test_assert((SELECT count(*)=2 FROM public.admin_eligible_professionals()));
            SELECT public.test_assert((SELECT count(*)=0 FROM public.admin_eligible_professionals() WHERE role<>'professional'));
        """)
        self.check_sql(as_user() + "SELECT * FROM public.admin_eligible_professionals();", '42501')

    def test_professional_cannot_assign_other_professionals_or_archive(self):
        self.check_sql(as_user() + f"""
            INSERT INTO public.patients(owner_id,dni,first_names,last_names,birth_date,sex)
                VALUES ('{U2}','98765432','Denied','Patient','1980-01-01','female');
        """, '42501')
        self.check_sql(as_user() + f"SELECT public.admin_set_patient_active('{P1}',false,'Denied');", '42501')
        self.check_sql(as_user() + f"UPDATE public.patients SET is_active=false WHERE id='{P1}';", '42501')

    def test_deactivation_keeps_history_and_blocks_new_evaluations(self):
        archive=as_user(ADMIN)+f"SELECT public.admin_set_patient_active('{P1}',false,'Patient archived'); RESET ROLE;"
        self.check_sql(three_images()+complete_result()+archive+as_user()+f"""
            SELECT public.test_assert((SELECT NOT is_active FROM public.patients WHERE id='{P1}'));
            SELECT public.test_assert((SELECT count(*)=1 FROM public.evaluations WHERE id='{E1}'));
            SELECT public.test_assert((SELECT count(*)=3 FROM public.evaluation_images WHERE evaluation_id='{E1}'));
            UPDATE public.patients SET first_names='Denied' WHERE id='{P1}';
            SELECT public.test_assert((SELECT first_names='First' FROM public.patients WHERE id='{P1}'));
        """)
        self.check_sql(archive+as_user()+f"INSERT INTO public.evaluations(patient_id,eye) VALUES('{P1}','left');", '23514')
        self.check_sql(self.pending_r2_metadata()+archive+f"SET LOCAL ROLE service_role;SELECT public.finish_r2_upload('{U1}','{E1}',{self.r2_objects()});", '23514')

    def test_reactivation_and_reason_are_guarded(self):
        self.check_sql(as_user(ADMIN)+f"SELECT public.admin_set_patient_active('{P1}',false,'');", '23514')
        self.check_sql(as_user(ADMIN)+f"""
            SELECT public.admin_set_patient_active('{P1}',false,'Archived');
            SELECT public.admin_set_patient_active('{P1}',true,NULL);
            SELECT public.test_assert((SELECT is_active AND deactivated_at IS NULL FROM public.patients WHERE id='{P1}'));
        """)
        self.check_sql(as_user(ADMIN)+f"""
            SELECT public.admin_set_patient_active('{P1}',false,'Archived');
            SELECT public.admin_update_user('{U1}','Disabled','professional',false);
            SELECT public.admin_set_patient_active('{P1}',true,NULL);
        """, '23514')

    def test_admin_cannot_author_new_evaluations(self):
        self.check_sql(as_user(ADMIN)+f"INSERT INTO public.evaluations(patient_id,eye) VALUES('{P1}','left');", '23514')

    def test_draft_rpc_is_atomic_and_idempotent(self):
        new_id = '30000000-0000-0000-0000-000000000099'
        metadata = "(SELECT jsonb_agg(jsonb_build_object('position', n, 'sha256', repeat(n::text,64), 'content_type', 'image/png', 'byte_size', 10)) FROM generate_series(1,3) n)"
        call = f"SELECT public.save_evaluation_draft('{new_id}', '{P1}', 'right', NULL, {metadata});"
        self.check_sql(as_user() + call + call + f"""
            SELECT public.test_assert((SELECT count(*) = 3 FROM public.evaluation_images WHERE evaluation_id = '{new_id}'));
            SELECT public.test_assert((SELECT status = 'draft' FROM public.evaluations WHERE id = '{new_id}'));
        """)

    def test_draft_rpc_rolls_back_all_rows_on_invalid_image(self):
        new_id = '30000000-0000-0000-0000-000000000099'
        self.check_sql(as_user() + f"""
            DO $$ BEGIN
                BEGIN
                    PERFORM public.save_evaluation_draft('{new_id}', '{P1}', 'right', NULL,
                        (SELECT jsonb_agg(jsonb_build_object('position', n, 'sha256', repeat('a',64), 'content_type', 'image/png', 'byte_size', 10)) FROM generate_series(1,3) n));
                    RAISE EXCEPTION 'Expected duplicate rejection';
                EXCEPTION WHEN unique_violation THEN NULL;
                END;
                PERFORM public.test_assert(NOT EXISTS (SELECT 1 FROM public.evaluations WHERE id = '{new_id}'));
            END $$;
        """)

    def test_draft_rpc_cannot_be_called_anonymously(self):
        self.check_sql("SET LOCAL ROLE anon; SELECT public.save_evaluation_draft(gen_random_uuid(), gen_random_uuid(), 'right', NULL, '[]');", "42501")

    def test_catalog_is_readonly_for_client(self):
        self.check_sql(as_user() + "UPDATE public.icdr_grades SET label = 'Changed' WHERE grade = 0;", "42501")


def main():
    with tempfile.TemporaryDirectory(prefix="retinazo-db-test-") as directory:
        env = Path(directory) / "postgres.env"
        env.write_text("POSTGRES_DB=retinazo_test\nPOSTGRES_PASSWORD=" + secrets.token_urlsafe(32) + "\n")
        os.chmod(env, 0o600)
        try:
            subprocess.run(["docker", "run", "--detach", "--rm", "--network", "none",
                            "--name", CONTAINER, "--env-file", str(env), IMAGE],
                           check=True, stdout=subprocess.DEVNULL, timeout=120)
            for _ in range(60):
                ready = subprocess.run(["docker", "exec", CONTAINER, "pg_isready", "-h", "127.0.0.1", "-U", "postgres", "-d", "retinazo_test"],
                                       capture_output=True, timeout=5)
                if ready.returncode == 0:
                    break
                time.sleep(0.5)
            else:
                raise RuntimeError("Test PostgreSQL did not become ready")
            execute((ROOT / "supabase/tests/auth_stub.sql").read_text())
            for migration in sorted((ROOT / "supabase/migrations").glob("*.sql")):
                execute("BEGIN;\n" + migration.read_text() + "\nCOMMIT;")
            execute(f"""
                INSERT INTO auth.users(id, email, email_confirmed_at, raw_user_meta_data) VALUES
                    ('{U1}', 'first@example.invalid', now(), '{{"full_name":"First account"}}'),
                    ('{U2}', 'second@example.invalid', now(), '{{"name":"Second account"}}'),
                    ('{U3}', 'unconfirmed@example.invalid', NULL, '{{"role":"admin"}}');
                UPDATE public.profiles SET role = 'admin' WHERE id = '{ADMIN}';
                INSERT INTO public.patients(id, owner_id, dni, first_names, last_names, birth_date, sex) VALUES
                    ('{P1}', '{U1}', '12345678', 'First', 'Patient', '1980-01-01', 'female'),
                    ('{P2}', '{U2}', '12345678', 'Second', 'Patient', '1980-01-01', 'male');
                INSERT INTO public.evaluations(id, patient_id, professional_id, eye) VALUES
                    ('{E1}', '{P1}', '{U1}', 'right'), ('{E2}', '{P2}', '{U2}', 'left');
                CREATE FUNCTION public.test_assert(value boolean) RETURNS void LANGUAGE plpgsql AS $$$$
                BEGIN IF value IS DISTINCT FROM true THEN RAISE EXCEPTION 'Test assertion failed'; END IF; END;
                $$$$;
            """.replace("$$$$", "$$"))
            result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(SchemaTests))
            return 0 if result.wasSuccessful() else 1
        finally:
            subprocess.run(["docker", "rm", "--force", "--volumes", CONTAINER], capture_output=True, timeout=30)


if __name__ == "__main__":
    raise SystemExit(main())
