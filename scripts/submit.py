import jwt, time, requests, sys, os, hashlib

KEY_ID = 'WDXGY9WX55'
ISSUER = '2be0734f-943a-4d61-9dc9-5d9045c46fec'
APP_ID = '6764072933'
BUILD_NUMBER = sys.argv[1]
SCREENSHOT_DIR = os.environ.get('SCREENSHOT_DIR', 'AppStoreScreenshots')

p8 = open('/tmp/asc_key.p8').read()

def make_token():
    return jwt.encode(
        {'iss': ISSUER, 'iat': int(time.time()), 'exp': int(time.time()) + 1200, 'aud': 'appstoreconnect-v1'},
        p8, algorithm='ES256', headers={'kid': KEY_ID}
    )

def headers():
    return {'Authorization': f'Bearer {make_token()}', 'Content-Type': 'application/json'}

def api(method, path, **kwargs):
    r = requests.request(method, f'https://api.appstoreconnect.apple.com/v1{path}',
        headers=headers(), **kwargs)
    return r

print(f'Waiting for build {BUILD_NUMBER} to be processed...')
build_id = None
for i in range(80):
    r = api('GET', f'/builds?filter[app]={APP_ID}&filter[version]={BUILD_NUMBER}&filter[processingState]=VALID&limit=1')
    data = r.json()
    if data.get('data'):
        build_id = data['data'][0]['id']
        print(f'Build ready: {build_id}')
        break
    print(f'  Waiting... ({i+1}/80)')
    time.sleep(30)

if not build_id:
    print('Build not found after 40 minutes.')
    sys.exit(0)

# Set export compliance
r = api('PATCH', f'/builds/{build_id}',
    json={'data': {'type': 'builds', 'id': build_id, 'attributes': {'usesNonExemptEncryption': False}}})
print(f'Export compliance: {r.status_code}')

# Cancel any blocking reviewSubmissions
canceled = False
for state in ['UNRESOLVED_ISSUES', 'READY_FOR_REVIEW', 'WAITING_FOR_REVIEW']:
    r = api('GET', f'/apps/{APP_ID}/reviewSubmissions?filter[state]={state}')
    for sub in r.json().get('data', []):
        sid = sub['id']
        api('PATCH', f'/reviewSubmissions/{sid}', json={
            'data': {'type': 'reviewSubmissions', 'id': sid, 'attributes': {'canceled': True}}
        })
        print(f'Canceled {sid}')
        canceled = True
if canceled:
    time.sleep(30)

# Find version
r = api('GET', f'/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&filter[appStoreState]=PREPARE_FOR_SUBMISSION,REJECTED,DEVELOPER_REJECTED&limit=1')
versions = r.json().get('data', [])
if versions:
    version_id = versions[0]['id']
    version_state = versions[0]['attributes']['appStoreState']
    print(f'Using version: {version_id} ({version_state})')
else:
    r = api('GET', f'/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=1')
    data = r.json()
    if data.get('data'):
        vs = data['data'][0]['attributes']['appStoreState']
        if vs in ('WAITING_FOR_REVIEW', 'IN_REVIEW'):
            print(f'Already in review ({vs}). Nothing to do.')
            sys.exit(0)
    r = api('POST', '/appStoreVersions', json={
        'data': {
            'type': 'appStoreVersions',
            'attributes': {'platform': 'IOS', 'versionString': '1.1'},
            'relationships': {'app': {'data': {'type': 'apps', 'id': APP_ID}}}
        }
    })
    if r.status_code not in (200, 201):
        print(f'Create version failed: {r.text[:500]}')
        sys.exit(1)
    version_id = r.json()['data']['id']
    print(f'Created version: {version_id}')

# Assign build
r = api('PATCH', f'/appStoreVersions/{version_id}/relationships/build',
    json={'data': {'type': 'builds', 'id': build_id}})
print(f'Build assigned: {r.status_code}')

# Update whatsNew
r = api('GET', f'/appStoreVersions/{version_id}/appStoreVersionLocalizations')
locs = r.json().get('data', [])
for loc in locs:
    loc_id = loc['id']
    api('PATCH', f'/appStoreVersionLocalizations/{loc_id}', json={
        'data': {
            'type': 'appStoreVersionLocalizations', 'id': loc_id,
            'attributes': {'whatsNew': 'UIの改善とパフォーマンス向上'}
        }
    })

# ── Clean up old screenshots ──
print('Cleaning up old screenshots...')
for loc in locs:
    loc_id = loc['id']
    r = api('GET', f'/appStoreVersionLocalizations/{loc_id}/appScreenshotSets')
    for ss_set in r.json().get('data', []):
        set_id = ss_set['id']
        r2 = api('GET', f'/appScreenshotSets/{set_id}/appScreenshots')
        for ss in r2.json().get('data', []):
            api('DELETE', f'/appScreenshots/{ss["id"]}')
        api('DELETE', f'/appScreenshotSets/{set_id}')
time.sleep(10)

# ── Upload fresh screenshots ──
DISPLAY_TYPES = {
    '': 'APP_IPHONE_67',
    'iphone_65': 'APP_IPHONE_65',
    'ipad_129': 'APP_IPAD_PRO_3GEN_129',
}

for subdir, display_type in DISPLAY_TYPES.items():
    ss_path = os.path.join(SCREENSHOT_DIR, subdir) if subdir else SCREENSHOT_DIR
    if not os.path.isdir(ss_path):
        continue
    pngs = sorted([f for f in os.listdir(ss_path) if f.endswith('.png')])
    if not pngs:
        continue
    print(f'\nUploading {len(pngs)} for {display_type}')

    for loc in locs:
        loc_id = loc['id']
        locale = loc['attributes']['locale']

        r = api('POST', '/appScreenshotSets', json={
            'data': {
                'type': 'appScreenshotSets',
                'attributes': {'screenshotDisplayType': display_type},
                'relationships': {'appStoreVersionLocalization': {'data': {'type': 'appStoreVersionLocalizations', 'id': loc_id}}}
            }
        })
        if r.status_code != 201:
            print(f'  Create set failed ({locale}): {r.status_code} {r.text[:200]}')
            continue
        set_id = r.json()['data']['id']

        for png in pngs:
            filepath = os.path.join(ss_path, png)
            filesize = os.path.getsize(filepath)
            with open(filepath, 'rb') as f:
                checksum = hashlib.md5(f.read()).hexdigest()

            r = api('POST', '/appScreenshots', json={
                'data': {
                    'type': 'appScreenshots',
                    'attributes': {'fileName': png, 'fileSize': filesize},
                    'relationships': {'appScreenshotSet': {'data': {'type': 'appScreenshotSets', 'id': set_id}}}
                }
            })
            if r.status_code != 201:
                print(f'  Reserve {png} failed: {r.status_code} {r.text[:200]}')
                continue

            ss_data = r.json()['data']
            ss_id = ss_data['id']
            upload_ops = ss_data['attributes'].get('uploadOperations', [])

            with open(filepath, 'rb') as f:
                file_data = f.read()
            for op in upload_ops:
                hdrs = {h['name']: h['value'] for h in op['requestHeaders']}
                requests.put(op['url'], headers=hdrs, data=file_data[op['offset']:op['offset']+op['length']])

            api('PATCH', f'/appScreenshots/{ss_id}', json={
                'data': {'type': 'appScreenshots', 'id': ss_id, 'attributes': {'uploaded': True, 'sourceFileChecksum': checksum}}
            })
            print(f'  {png} -> {locale}')

# ── Wait for screenshot processing ──
print('\nWaiting for screenshots to process...')
for wait in range(20):
    processing = False
    for loc in locs:
        r2 = api('GET', f'/appStoreVersionLocalizations/{loc["id"]}/appScreenshotSets')
        for ss_set in r2.json().get('data', []):
            r3 = api('GET', f'/appScreenshotSets/{ss_set["id"]}/appScreenshots')
            for ss in r3.json().get('data', []):
                state = ss['attributes'].get('assetDeliveryState', {}).get('state', '')
                if state not in ('COMPLETE', 'UPLOAD_COMPLETE'):
                    processing = True
    if not processing:
        print('Screenshots ready!')
        break
    print(f'  Processing... ({wait+1}/20)')
    time.sleep(30)

# ── Submit ──
submission_id = None

# Try reusing existing READY_FOR_REVIEW submission
r = api('GET', f'/apps/{APP_ID}/reviewSubmissions?filter[state]=READY_FOR_REVIEW&limit=10')
for sub in r.json().get('data', []):
    sid = sub['id']
    r2 = api('GET', f'/reviewSubmissions/{sid}/items')
    items = r2.json().get('data', [])
    if not items:
        submission_id = sid
        print(f'Reusing submission: {submission_id}')
        break

if not submission_id:
    for attempt in range(5):
        r = api('POST', '/reviewSubmissions', json={
            'data': {
                'type': 'reviewSubmissions',
                'relationships': {'app': {'data': {'type': 'apps', 'id': APP_ID}}}
            }
        })
        if r.status_code == 201:
            submission_id = r.json()['data']['id']
            print(f'Created submission: {submission_id}')
            break
        print(f'Create attempt {attempt+1}/5: {r.status_code} {r.text[:300]}')
        time.sleep(15)

if not submission_id:
    print('Could not create review submission')
    sys.exit(1)

r = api('POST', '/reviewSubmissionItems', json={
    'data': {
        'type': 'reviewSubmissionItems',
        'relationships': {
            'reviewSubmission': {'data': {'type': 'reviewSubmissions', 'id': submission_id}},
            'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': version_id}}
        }
    }
})
print(f'Add item: {r.status_code}')
if r.status_code != 201:
    print(f'  {r.text[:1000]}')
    sys.exit(1)

r = api('PATCH', f'/reviewSubmissions/{submission_id}', json={
    'data': {'type': 'reviewSubmissions', 'id': submission_id, 'attributes': {'submitted': True}}
})
if r.status_code == 200:
    print(f'Submitted! State: {r.json()["data"]["attributes"]["state"]}')
else:
    print(f'Submit failed: {r.status_code} {r.text[:1000]}')
    sys.exit(1)
