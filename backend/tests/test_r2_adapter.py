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
