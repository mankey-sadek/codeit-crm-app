"""Records the API answers the app's screen tests use (app/test/fixtures/*.json) from a TEST CRM.

    SMOKE_PASSWORD=... python3 record_fixtures.py http://127.0.0.1:8000/api/mobile/v1 admin@example.com ../../app/test/fixtures/api.json

Use a CRM with made-up data only: the repository is public.
"""
import json, sys, importlib.util, os
OUT = sys.argv[3]
sys.argv = sys.argv[:3]
spec = importlib.util.spec_from_file_location('s', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'api_smoke.py'))
s = importlib.util.module_from_spec(spec); spec.loader.exec_module(s)
st, d = s.call('POST', 'auth/login', {'email': s.EMAIL, 'password': s.PASSWORD, 'device_name': 'rec'})
s.TOKEN = d.get('token') or d['data']['token']
out = {}
try:
    for path, details in s.SCREENS.items():
        st, d = s.call('GET', path)
        if st != 200: continue
        out[path.split('?')[0]] = d
        pid = s.first_id(d)
        for t in details + (['invoices/{id}/form'] if path == 'invoices' else []):
            if not pid: continue
            p = t.format(id=pid); st2, d2 = s.call('GET', p)
            if st2 == 200: out[p] = d2
finally:
    s.call('POST', 'auth/logout')
base = sys.argv[1].split('/api/')[0]
txt = json.dumps(out, ensure_ascii=False, indent=0).replace(base, 'https://crm.example.test')
open(OUT, 'w').write(txt)
print(len(out), 'responses', len(txt)//1024, 'KB')
