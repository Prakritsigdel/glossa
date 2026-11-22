import urllib.request, json, time

base = 'http://127.0.0.1:8000/api/v1'

def post(url, data, token=None):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    req = urllib.request.Request(url, data=json.dumps(data).encode(), headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode())

def get(url, token=None):
    headers = {}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        return resp.status, json.loads(resp.read().decode())

# 1. Register a fresh user
email = f'journey_full_{int(time.time())}@glossa.app'
status, reg = post(f'{base}/auth/register', {'name': 'Full Journey Tester', 'email': email, 'password': 'password123'})
token = reg['access_token']
print(f'1. Registered user {email}, status: {status}, initial XP: {reg["user"]["xp"]}')

# Check initial lessons: lesson 1 current, lesson 2 locked
status, lessons = get(f'{base}/lessons?course_id=en_ne', token)
l1 = next(l for l in lessons if l['id'] == 'en_ne_u1_l1')
l2 = next(l for l in lessons if l['id'] == 'en_ne_u1_l2')
print(f'   Initial lesson 1 status: {l1["status"]}, lesson 2 status: {l2["status"]}')

# 2. Check each exercise individually via /answer
mw_pairs = {
    'en_ne_u1_l1_mw_d1': 'en_ne_u1_l1_mw_e1',
    'en_ne_u1_l1_mw_d2': 'en_ne_u1_l1_mw_e2',
    'en_ne_u1_l1_mw_d3': 'en_ne_u1_l1_mw_e3',
    'en_ne_u1_l1_mw_d4': 'en_ne_u1_l1_mw_e4',
}

# Test matchWords partial and complete check
status, res = post(f'{base}/lessons/en_ne_u1_l1/answer', {
    'exercise_id': 'en_ne_u1_l1_mw',
    'selected_pairs': {'en_ne_u1_l1_mw_d1': 'en_ne_u1_l1_mw_e1'}
}, token)
print(f'2a. Check single pair matchWords: status={status}, result={res}')

# Test fillBlank check
status, res = post(f'{base}/lessons/en_ne_u1_l1/answer', {
    'exercise_id': 'en_ne_u1_l1_fb',
    'selected_option_id': 'en_ne_u1_l1_fb_a'
}, token)
print(f'2b. Check fillBlank answer: status={status}, result={res}')

# Test pictureToWord check
status, res = post(f'{base}/lessons/en_ne_u1_l1/answer', {
    'exercise_id': 'en_ne_u1_l1_ptw',
    'selected_option_id': 'en_ne_u1_l1_ptw_a'
}, token)
print(f'2c. Check pictureToWord answer: status={status}, result={res}')

# Test wordToPicture check
status, res = post(f'{base}/lessons/en_ne_u1_l1/answer', {
    'exercise_id': 'en_ne_u1_l1_wtp',
    'selected_option_id': 'en_ne_u1_l1_wtp_a'
}, token)
print(f'2d. Check wordToPicture answer: status={status}, result={res}')

# 3. Test submitting INCOMPLETE attempt (only 1 exercise answered)
status, res = post(f'{base}/lessons/en_ne_u1_l1/attempts', {
    'answers': [{'exercise_id': 'en_ne_u1_l1_fb', 'selected_option_id': 'en_ne_u1_l1_fb_a'}]
}, token)
print(f'3. Incomplete attempt submission: status={status}, detail={res.get("detail")}')

# 4. Test submitting COMPLETE attempt with all 4 exercises
complete_answers = [
    {
        'exercise_id': 'en_ne_u1_l1_mw',
        'selected_pairs': mw_pairs,
    },
    {
        'exercise_id': 'en_ne_u1_l1_fb',
        'selected_option_id': 'en_ne_u1_l1_fb_a',
    },
    {
        'exercise_id': 'en_ne_u1_l1_ptw',
        'selected_option_id': 'en_ne_u1_l1_ptw_a',
    },
    {
        'exercise_id': 'en_ne_u1_l1_wtp',
        'selected_option_id': 'en_ne_u1_l1_wtp_a',
    },
]

completed_val = res.get("completed")
already_val = res.get("already_completed")
xp_val = res.get("xp_earned")
user_xp_val = res.get("user", {}).get("xp")
status, res = post(f'{base}/lessons/en_ne_u1_l1/attempts', {'answers': complete_answers}, token)
print(f'4. Complete attempt submission: status={status}, completed={res.get("completed")}, already_completed={res.get("already_completed")}, xp_earned={res.get("xp_earned")}, user_xp={res.get("user", {}).get("xp")}')

# 5. Check duplicate attempt submission (idempotency check)
status, res_dup = post(f'{base}/lessons/en_ne_u1_l1/attempts', {'answers': complete_answers}, token)
print(f'5. Duplicate attempt submission: status={status}, completed={res_dup.get("completed")}, already_completed={res_dup.get("already_completed")}, xp_earned={res_dup.get("xp_earned")}')

# 6. Verify lesson 2 is now unlocked!
status, lessons_after = get(f'{base}/lessons?course_id=en_ne', token)
l1_after = next(l for l in lessons_after if l['id'] == 'en_ne_u1_l1')
l2_after = next(l for l in lessons_after if l['id'] == 'en_ne_u1_l2')
print(f'6. Lessons after completion: lesson 1 status={l1_after["status"]}, lesson 2 status={l2_after["status"]}')
