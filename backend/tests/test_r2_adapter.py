from botocore.stub import Stubber
from retinazo_api.infrastructure.r2 import R2Store
from test_gateway import settings


def test_r2_adapter_targets_private_object_and_short_lived_link():
    store=R2Store(settings())
    with Stubber(store.client) as stub:
        stub.add_response('put_object',{}, {'Bucket':'retinazo-retinas','Key':'evaluations/test/image.png',
            'Body':b'synthetic','ContentType':'image/png','CacheControl':'private, no-store'})
        store.put('evaluations/test/image.png',b'synthetic','image/png')
        stub.assert_no_pending_responses()
    from urllib.parse import urlsplit,parse_qs
    url=urlsplit(store.signed_get('evaluations/test/image.png'))
    assert url.scheme=='https' and url.hostname.endswith('.r2.cloudflarestorage.com')
    assert parse_qs(url.query)['X-Amz-Expires']==['60']
    assert 'synthetic-secret' not in url.query
    store.close()


def test_r2_read_missing_and_bounded_body():
    from io import BytesIO
    from botocore.response import StreamingBody
    from retinazo_api.domain.storage import StorageFailure
    import pytest
    store = R2Store(settings())
    with Stubber(store.client) as stub:
        params = {"Bucket": store.bucket, "Key": "synthetic/preview.jpg"}
        stub.add_client_error("get_object", service_error_code="NoSuchKey", http_status_code=404, expected_params=params)
        assert store.read(params['Key'], 10) is None
        stub.add_response("get_object", {"Body": StreamingBody(BytesIO(b'abc'), 3), "ContentLength": 3}, params)
        assert store.read(params['Key'], 10) == b'abc'
        stub.add_response("get_object", {"Body": StreamingBody(BytesIO(b'abc'), 3), "ContentLength": 3}, params)
        with pytest.raises(StorageFailure):
            store.read(params['Key'], 2)
        stub.assert_no_pending_responses()
    store.close()
