"""Local simulation API. No card data or real payments. Bind to loopback only."""
import json
import os
import re
import sqlite3
import uuid
from pathlib import Path

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, StrictInt

CAMPAIGNS = {
    'kitchen': 'Community Kitchen',
    'learning': 'Learning Kits',
    'coast': 'Coastal Care',
}
KEY_PATTERN = re.compile(r'^[a-zA-Z0-9_-]{8,80}$')

class DonationInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    campaign_id: str
    amount_cents: StrictInt
    currency: str = 'EUR'
    scenario: str = 'success'

def create_app(db_path=None):
    path = str(db_path or os.environ.get('GIVEFLOW_DB', Path(__file__).parent / 'giveflow.sqlite3'))
    app = FastAPI(title='GiveFlow simulation API', version='1.0.0')
    # Only for a local Flutter development server on the documented port.
    app.add_middleware(CORSMiddleware, allow_origins=['http://localhost:8080'],
                       allow_methods=['GET', 'POST', 'DELETE'],
                       allow_headers=['Content-Type', 'Idempotency-Key'])

    def connect():
        conn = sqlite3.connect(path, timeout=10)
        conn.row_factory = sqlite3.Row
        return conn

    with connect() as conn:
        conn.execute('''CREATE TABLE IF NOT EXISTS donations (
            key TEXT PRIMARY KEY, fingerprint TEXT NOT NULL,
            receipt TEXT NOT NULL, created INTEGER NOT NULL
        )''')

    def validate_key(key):
        if not key or not KEY_PATTERN.fullmatch(key):
            raise HTTPException(400, 'Idempotency-Key must contain 8 to 80 letters, digits, underscores or hyphens.')

    @app.get('/health')
    def health():
        return {'status': 'ok', 'mode': 'simulation'}

    @app.get('/campaigns')
    def campaigns():
        return [{'id': k, 'name': v} for k, v in CAMPAIGNS.items()]

    @app.post('/donations')
    def donate(body: DonationInput, idempotency_key: str = Header(default=None)):
        validate_key(idempotency_key)
        if body.campaign_id not in CAMPAIGNS:
            raise HTTPException(422, 'Unknown campaign.')
        if body.currency != 'EUR' or not 100 <= body.amount_cents <= 50000:
            raise HTTPException(422, 'Use EUR and an amount between 100 and 50000 cents.')
        if body.scenario not in ('success', 'declined', 'timeout', 'offline'):
            raise HTTPException(422, 'Unknown simulation scenario.')
        fingerprint = json.dumps([body.campaign_id, body.amount_cents, body.currency])
        with connect() as conn:
            # Serialises check+insert so simultaneous requests cannot create duplicates.
            conn.execute('BEGIN IMMEDIATE')
            existing = conn.execute('SELECT * FROM donations WHERE key=?', (idempotency_key,)).fetchone()
            if existing:
                if existing['fingerprint'] != fingerprint:
                    raise HTTPException(409, 'This key belongs to a different donation.')
                return json.loads(existing['receipt'])
            if body.scenario == 'offline':
                raise HTTPException(503, 'Simulated offline state. No donation was recorded.')
            import time
            receipt = {'id': str(uuid.uuid4()), 'key': idempotency_key,
                       'campaign_id': body.campaign_id, 'campaign_name': CAMPAIGNS[body.campaign_id],
                       'amount_cents': body.amount_cents, 'currency': 'EUR',
                       'status': 'declined' if body.scenario == 'declined' else 'succeeded',
                       'created_at': int(time.time() * 1000), 'simulated': True}
            conn.execute('INSERT INTO donations VALUES (?, ?, ?, ?)',
                         (idempotency_key, fingerprint, json.dumps(receipt), receipt['created_at']))
        # Commit before simulating a lost response. The client must reconcile this key.
        if body.scenario == 'timeout':
            raise HTTPException(504, 'Simulated response timeout. Check the same key before another attempt.')
        return receipt

    @app.get('/donations/by-key/{key}')
    def by_key(key: str):
        validate_key(key)
        with connect() as conn:
            result = conn.execute('SELECT receipt FROM donations WHERE key=?', (key,)).fetchone()
        if not result:
            raise HTTPException(404, 'No donation found for this key.')
        return json.loads(result['receipt'])

    @app.get('/donations')
    def history():
        with connect() as conn:
            rows = conn.execute('SELECT receipt FROM donations ORDER BY created DESC, key').fetchall()
        return [json.loads(row['receipt']) for row in rows]

    return app

app = create_app()
