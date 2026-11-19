#!/usr/bin/env python3
"""Read-only smoke test of the app API: signs in, opens every screen's endpoint, signs out.

Every GET the app uses must answer 200 (or 403 when the role can't open it), never 404/500,
and always JSON. Detail endpoints are tried with the first id their list returns.
Nothing is created or changed.

    python3 api_smoke.py https://crm.coditvision.com/api/mobile/v1 someone@company.com
    (asks for the password; or set SMOKE_PASSWORD)
"""
import getpass
import json
import os
import sys
import urllib.error
import urllib.request

BASE = sys.argv[1].rstrip('/') if len(sys.argv) > 1 else 'http://127.0.0.1:8000/api/mobile/v1'
EMAIL = sys.argv[2] if len(sys.argv) > 2 else 'admin@example.com'
PASSWORD = os.environ.get('SMOKE_PASSWORD') or getpass.getpass(f'password for {EMAIL}: ')

TOKEN = None


def call(method, path, body=None):
    req = urllib.request.Request(f'{BASE}/{path}', method=method, data=json.dumps(body).encode() if body is not None else None)
    req.add_header('Accept', 'application/json')
    req.add_header('Content-Type', 'application/json')
    if TOKEN:
        req.add_header('Authorization', f'Bearer {TOKEN}')
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw, status = r.read(), r.status
    except urllib.error.HTTPError as e:
        raw, status = e.read(), e.code
    try:
        return status, json.loads(raw or b'null')
    except ValueError:
        return status, {'_not_json': raw[:200].decode('utf8', 'replace')}


def first_id(data):
    """First "id" anywhere in a list response (lists are nested differently per screen)."""
    if isinstance(data, dict):
        if isinstance(data.get('id'), int) and data.get('id') > 0 and len(data) > 1:
            return data['id']
        for k, v in data.items():
            if k in ('me', 'users', 'stats', 'counts', 'names', 'groups', 'roles'):
                continue
            r = first_id(v)
            if r:
                return r
    if isinstance(data, list):
        for v in data:
            r = first_id(v)
            if r:
                return r
    return None


# list endpoint -> detail endpoints filled with the first id of that list
SCREENS = {
    'home': [], 'me': [], 'notifications': [], 'search?q=te': [], 'pipelines': [], 'forms/options': [],
    'leads': ['leads/{id}'], 'leads/board': [], 'persons': ['persons/{id}'], 'organizations': ['organizations/{id}'],
    'activities': [], 'quotes': ['quotes/{id}'], 'products': [],
    'mail/inbox': ['mail/inbox/{id}'], 'mail/sent': [],
    'projects': ['projects/{id}', 'projects/{id}/form'], 'tasks': ['tasks/{id}', 'tasks/{id}/form'],
    'tickets': ['tickets/{id}'], 'invoices': ['invoices/{id}'], 'support-packages': [],
    'chat': ['chat/{id}/messages'], 'chat/users': [], 'chat/monitor': ['chat/monitor/{id}'],
    'hr/me': [], 'hr/employees': ['hr/employees/{id}'], 'hr/attendance': [], 'hr/leaves': [], 'hr/payroll': ['hr/payslips/{id}'],
    'careers': ['careers/{id}'],
    'settings': [], 'settings/users': [], 'settings/roles': [], 'settings/pipelines': [], 'settings/groups': [],
    'settings/sources': [], 'settings/types': [], 'settings/tags': [], 'settings/hr-departments': [], 'settings/hr': [],
    'settings/email-templates': [],
}


def main():
    global TOKEN
    status, d = call('POST', 'auth/login', {'email': EMAIL, 'password': PASSWORD, 'device_name': 'api smoke test'})
    TOKEN = (d or {}).get('token') or ((d or {}).get('data') or {}).get('token')
    if status != 200 or not TOKEN:
        print(f'login failed: {status} {d}')
        return 2
    bad, ok, denied = [], 0, 0
    try:
        for path, details in SCREENS.items():
            status, d = call('GET', path)
            if status == 403:
                denied += 1
                if '-v' in sys.argv:
                    print('  not allowed: ' + path)
                continue
            if status != 200 or '_not_json' in (d or {}):
                bad.append(f'{status} GET {path} {str(d)[:160]}')
                continue
            ok += 1
            pid = first_id(d)
            for t in details:
                if not pid:
                    continue
                p = t.format(id=pid)
                s2, d2 = call('GET', p)
                if s2 == 403:
                    denied += 1
                elif s2 != 200 or '_not_json' in (d2 or {}):
                    bad.append(f'{s2} GET {p} {str(d2)[:160]}')
                else:
                    ok += 1
    finally:
        call('POST', 'auth/logout')
    print(f'{ok} ok, {denied} not allowed for this role, {len(bad)} broken')
    for b in bad:
        print('  ' + b)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
