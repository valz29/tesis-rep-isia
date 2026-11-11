#!/usr/bin/env python3
"""Opt-in remote check using disposable synthetic accounts, records and PNGs.

Run with backend/.venv/bin/python scripts/smoke_remote_images.py --run.
Requires the protected backend/.env and a deployed IMAGE_API_URL. Never prints
credentials, sessions, signed URLs or data from existing patients.
"""
from io import BytesIO
from pathlib import Path
import argparse
import hashlib
import secrets
from uuid import uuid4

import boto3
from botocore.config import Config
from dotenv import dotenv_values
import httpx
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def check(response, statuses, label):
    if response.status_code not in statuses:
        raise RuntimeError(f"{label}: HTTP {response.status_code}")
    return response


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true", required=True)
    parser.parse_args()
    config = dotenv_values(ROOT / "backend/.env")
    base = config["SUPABASE_URL"].rstrip("/")
    api = config["IMAGE_API_URL"].rstrip("/")
    project = base.split("//")[1].split(".")[0]
    server_key = config["SUPABASE_SERVICE_KEY"]
    privileged = {"apikey": server_key}
    if not server_key.startswith("sb_secret_"):
        privileged["Authorization"] = "Bearer " + server_key
    management = {"Authorization": "Bearer " + config["SUPABASE_ACCESS_TOKEN"]}
    account_ids = []
    patient_id, evaluation_id = str(uuid4()), str(uuid4())
    run_id = uuid4().hex
    store = boto3.client(
        "s3", endpoint_url=f"https://{config['R2_ACCOUNT_ID']}.r2.cloudflarestorage.com",
        aws_access_key_id=config["R2_ACCESS_KEY_ID"],
        aws_secret_access_key=config["R2_SECRET_ACCESS_KEY"], region_name="auto",
        config=Config(signature_version="s3v4", connect_timeout=15, read_timeout=30,
                      request_checksum_calculation="when_required",
                      response_checksum_validation="when_required"),
    )
    cleanup_errors = []
    with httpx.Client(timeout=180, follow_redirects=False) as client:
        def sql(query):
            result = client.post(
                f"https://api.supabase.com/v1/projects/{project}/database/query",
                headers=management, json={"query": query},
            )
            return check(result, (200, 201), "Synthetic SQL operation")

        def create_actor(number):
            email = f"retinazo-smoke-{run_id}-{number}@example.com"
            password = secrets.token_urlsafe(32)
            result = check(client.post(
                base + "/auth/v1/admin/users", headers=privileged,
                json={"email": email, "password": password, "email_confirm": True,
                      "user_metadata": {"full_name": "Synthetic storage check"}},
            ), (200, 201), "Create disposable account")
            user_id = result.json()["id"]
            account_ids.append(user_id)
            session = check(client.post(
                base + "/auth/v1/token?grant_type=password",
                headers={"apikey": config["SUPABASE_PUBLISHABLE_KEY"]},
                json={"email": email, "password": password},
            ), (200,), "Disposable account sign-in").json()
            return user_id, {
                "apikey": config["SUPABASE_PUBLISHABLE_KEY"],
                "Authorization": "Bearer " + session["access_token"],
            }

        try:
            check(client.get(api + "/health"), (200,), "API health")
            owner_id, owner = create_actor(1)
            other_id, other = create_actor(2)
            check(client.post(base + "/rest/v1/patients", headers=owner, json={
                "id": patient_id, "dni": "00000000", "first_names": "Synthetic",
                "last_names": "Storage check", "birth_date": "1980-01-01", "sex": "female",
            }), (201,), "Create disposable patient under owner RLS")
            pictures, metadata = [], []
            for position in range(1, 4):
                buffer = BytesIO()
                Image.new("RGB", (32, 32), (position * 50, 35, 20)).save(buffer, "PNG")
                content = buffer.getvalue()
                pictures.append(content)
                metadata.append({"position": position, "sha256": hashlib.sha256(content).hexdigest(),
                                 "content_type": "image/png", "byte_size": len(content)})
            check(client.post(base + "/rest/v1/rpc/save_evaluation_draft", headers=owner, json={
                "evaluation_id_input": evaluation_id, "patient_id_input": patient_id,
                "eye_input": "right", "observations_input": "Disposable synthetic storage check",
                "images_input": metadata,
            }), (200,), "Save three-image draft under owner RLS")
            route = api + f"/v1/evaluations/{evaluation_id}/images"
            owner_api = {"Authorization": owner["Authorization"]}
            other_api = {"Authorization": other["Authorization"]}
            check(client.get(route), (401,), "Anonymous access denied")
            check(client.get(route, headers=other_api), (404,), "Other professional denied")
            malformed = [("files", (f"{i}.png", b"invalid" if i == 1 else content, "image/png"))
                         for i, content in enumerate(pictures, 1)]
            check(client.put(route, headers=owner_api, files=malformed), (409,), "Altered image denied")
            files = [("files", (f"{i}.png", content, "image/png"))
                     for i, content in enumerate(pictures, 1)]
            check(client.put(route, headers=owner_api, files=files), (204,), "Upload three images")
            check(client.put(route, headers=owner_api, files=files), (204,), "Idempotent upload retry")
            result = check(client.get(
                base + "/rest/v1/evaluations", headers=owner,
                params={"id": "eq." + evaluation_id,
                        "select": "status,evaluation_images(position,upload_status,storage_provider),results(*)"},
            ), (200,), "Reload persisted evaluation").json()[0]
            assert result["status"] == "pending_analysis"
            assert not result["results"]
            assert len(result["evaluation_images"]) == 3
            assert all(row["upload_status"] == "uploaded" and row["storage_provider"] == "cloudflare_r2"
                       for row in result["evaluation_images"])
            links = check(client.get(route, headers=owner_api), (200,), "Reload image links").json()["images"]
            assert len(links) == 3
            for link in links:
                # No Supabase bearer is forwarded to R2.
                downloaded = check(client.get(link["url"]), (200,), "Signed R2 download").content
                assert downloaded == pictures[link["position"] - 1]
            sql(f"UPDATE public.profiles SET role='admin' WHERE id='{other_id}'::uuid;")
            check(client.get(route, headers=other_api), (200,), "Administrator can access owner images")
            check(client.put(route, headers=other_api, files=files), (403,), "Administrator cannot author image uploads")
            eligible = check(client.post(base + '/rest/v1/rpc/admin_eligible_professionals',
                                        headers=other, json={'query_input': ''}),
                             (200,), 'Eligible professionals').json()
            assert all(row['role'] == 'professional' and row['id'] != other_id for row in eligible)
            check(client.post(base + '/rest/v1/rpc/admin_reassign_patient', headers=other,
                              json={'patient_id_input': patient_id, 'owner_id_input': other_id}),
                  (400,), 'Administrator cannot own a patient')
            activity = base + '/rest/v1/rpc/admin_set_patient_active'
            check(client.post(activity, headers=owner, json={
                'patient_id_input': patient_id, 'active_input': False, 'reason_input': 'Denied',
            }), (403,), 'Professional cannot deactivate patient')
            check(client.post(activity, headers=other, json={
                'patient_id_input': patient_id, 'active_input': False, 'reason_input': 'Synthetic lifecycle check',
            }), (204, 200), 'Administrator deactivates patient')
            check(client.put(route, headers=owner_api, files=files), (409,), 'Inactive patient blocks uploads')
            assert len(check(client.get(route, headers=owner_api), (200,),
                             'Inactive patient retains image history').json()['images']) == 3
            check(client.post(activity, headers=other, json={
                'patient_id_input': patient_id, 'active_input': True, 'reason_input': None,
            }), (204, 200), 'Administrator reactivates patient')
            check(client.put(route, headers=owner_api, files=files), (204,), 'Reactivated patient accepts retry')
            sql(f"UPDATE public.profiles SET is_active=false WHERE id='{other_id}'::uuid;")
            check(client.get(route, headers=other_api), (403,), "Disabled account denied")
            print("PASS: owner upload/retry, three persisted images, signed downloads and byte integrity.")
            print("PASS: anonymous/other professional denied, admin allowed, disabled account denied.")
            print("PASS: evaluation remains pending_analysis; no prediction created.")
            print("PASS: professional-only responsibility; admin deactivation/reactivation preserves image history.")
        finally:
            # Restrict every cleanup operation to IDs generated by this run.
            if account_ids:
                try:
                    sql(f"BEGIN; DELETE FROM public.evaluations WHERE id='{evaluation_id}'::uuid "
                        f"AND professional_id='{account_ids[0]}'::uuid; "
                        f"DELETE FROM public.patients WHERE id='{patient_id}'::uuid "
                        f"AND owner_id='{account_ids[0]}'::uuid; COMMIT;")
                except Exception:
                    cleanup_errors.append("synthetic clinical records")
            try:
                rows = store.list_objects_v2(Bucket=config["R2_BUCKET"], Prefix=f"evaluations/{evaluation_id}/")
                for item in rows.get("Contents", []):
                    store.delete_object(Bucket=config["R2_BUCKET"], Key=item["Key"])
            except Exception:
                cleanup_errors.append("synthetic R2 objects")
            for user_id in account_ids:
                try:
                    check(client.delete(base + "/auth/v1/admin/users/" + user_id,
                                        headers=privileged), (200,), "Remove disposable account")
                except Exception:
                    cleanup_errors.append("disposable account " + user_id)
            store.close()
            if cleanup_errors:
                raise RuntimeError("Cleanup incomplete: " + ", ".join(cleanup_errors))
            print("Cleanup completed: disposable records, accounts and R2 objects removed.")


if __name__ == "__main__":
    main()
