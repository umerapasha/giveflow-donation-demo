from concurrent.futures import ThreadPoolExecutor

import pytest
from fastapi.testclient import TestClient
from backend.app import create_app

@pytest.fixture
def client(tmp_path):
    return TestClient(create_app(tmp_path / 'test.sqlite3'))

def send(client, key='request_1234', **updates):
    data={'campaign_id':'kitchen', 'amount_cents':1000, 'currency':'EUR', 'scenario':'success'}
    data.update(updates)
    return client.post('/donations', json=data, headers={'Idempotency-Key':key})

def test_success_and_history(client):
    receipt=send(client).json()
    assert receipt['status']=='succeeded' and receipt['simulated'] is True
    assert client.get('/donations').json()==[receipt]

def test_replay_is_one_record(client):
    one=send(client).json()
    assert send(client).json()==one
    assert len(client.get('/donations').json())==1

def test_conflicting_key_is_rejected(client):
    send(client)
    assert send(client, amount_cents=2000).status_code==409

def test_concurrent_replays_create_one_record(client):
    with ThreadPoolExecutor(max_workers=8) as pool:
        receipts=list(pool.map(lambda _: send(client).json(), range(8)))
    assert len({r['id'] for r in receipts})==1
    assert len(client.get('/donations').json())==1

def test_timeout_reconciliation(client):
    assert send(client, scenario='timeout').status_code==504
    recovered=client.get('/donations/by-key/request_1234').json()
    assert recovered['status']=='succeeded'
    assert send(client, scenario='success').json()==recovered
    assert len(client.get('/donations').json())==1

def test_offline_does_not_record(client):
    assert send(client, scenario='offline').status_code==503
    assert client.get('/donations').json()==[]

def test_decline_is_not_success(client):
    assert send(client, scenario='declined').json()['status']=='declined'

@pytest.mark.parametrize('value',[0,99,50001,-100,100.5,'1000',True])
def test_bad_amount(client,value):
    assert send(client,amount_cents=value).status_code==422
    assert client.get('/donations').json()==[]

def test_boundaries(client):
    assert send(client,key='minimum_123',amount_cents=100).status_code==200
    assert send(client,key='maximum_123',amount_cents=50000).status_code==200

def test_bad_campaign_currency_and_scenario(client):
    for update in [{'campaign_id':'other'},{'currency':'USD'},{'scenario':'other'}]:
        assert send(client,**update).status_code==422

def test_missing_or_bad_key(client):
    assert send(client,key='bad').status_code==400
    assert client.post('/donations',json={'campaign_id':'kitchen','amount_cents':1000}).status_code==400

def test_unknown_key(client):
    assert client.get('/donations/by-key/missing_key').status_code==404

def test_health_and_campaigns(client):
    assert client.get('/health').json()['mode']=='simulation'
    assert len(client.get('/campaigns').json())==3

def test_persistence_across_app_restart(tmp_path):
    path=tmp_path/'persist.sqlite3'
    one=send(TestClient(create_app(path))).json()
    assert TestClient(create_app(path)).get('/donations').json()==[one]
