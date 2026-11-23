import urllib.request, json, time

base = 'http://127.0.0.1:8000/api/v1'

def post(url, data, token=None):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    req = urllib.request.Request(url, data=json.dumps(data).encode(), headers=headers)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())

def get(url, token=None):
    headers = {}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())

# 1. Register a new user
email = f'learner_{int(time.time())}@glossa.app'
reg = post(f'{base}/auth/register', {'name': 'Learner Hero', 'email': email, 'password': 'password123'})
token = reg['access_token']
print(f'User registered: {reg["user"]["name"]} (active_course_id={reg["user"]["active_course_id"]})')

# 2. Get exercises for en_ne_u1_l1
exercises = get(f'{base}/lessons/en_ne_u1_l1/exercises', token)
print(f'Fetched {len(exercises)} exercises:')

answers_payload = []
for ex in exercises:
    print(f'  Exercise {ex["id"]} [{ex["type"]}]: {ex["instruction"]}')
    # Check answer for each exercise
    if ex['type'] == 'matchWords':
        # What is the pair?
        # Let's inspect options
        print('    Options in matchWords:', [(o['id'], o['text'], o.get('is_devanagari')) for o in ex['options']])
    else:
        print('    Options:', [(o['id'], o['text']) for o in ex['options']])
