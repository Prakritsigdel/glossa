"""PostgreSQL integration test for concurrent XP reward protection.

Tests against the isolated glossa_test database with the partial unique
index on attempts (user_id, lesson_id) WHERE is_correct = true.

Each test uses its own connection to avoid transaction state issues.
"""

from __future__ import annotations

import psycopg
import sys


def get_conn():
    return psycopg.connect(
        "host=localhost port=5432 dbname=glossa_test user=glossa password=glossa",
        autocommit=False,
    )


def setup_user_and_lesson(conn):
    """Create a test user, published lesson with exercises, return ids."""
    cur = conn.cursor()
    # Clean up any prior test data
    cur.execute("DELETE FROM attempts WHERE lesson_id = 'ct_lesson'")
    cur.execute("DELETE FROM exercises WHERE lesson_id = 'ct_lesson'")
    cur.execute("DELETE FROM lessons WHERE id = 'ct_lesson'")
    cur.execute("DELETE FROM lesson_vocabulary WHERE lesson_id = 'ct_lesson'")
    cur.execute("DELETE FROM users WHERE id IN (99999, 99998)")
    cur.execute("DELETE FROM units WHERE id = 99999")
    cur.execute("DELETE FROM courses WHERE id = 'ct_course'")
    cur.execute("DELETE FROM languages WHERE id = 'ct_lang'")

    # Language
    cur.execute(
        "INSERT INTO languages (id, name_english, name_native, script, is_active) "
        "VALUES ('ct_lang','TestLang','Test','Latin',true)"
    )
    # Course
    cur.execute(
        "INSERT INTO courses (id, source_language_id, target_language_id, "
        "name, description, is_published) "
        "VALUES ('ct_course','ct_lang','ct_lang','Test','Test',true)"
    )
    # Unit
    cur.execute(
        "INSERT INTO units (id, course_id, sequence, title, description) "
        "VALUES (99999, 'ct_course', 1, 'Test Unit', 'Test')"
    )
    # User
    cur.execute(
        "INSERT INTO users (id, name, email, password_hash, hero_index, hero_class_name, "
        "language_id, streak, xp, level, words_found, lessons_completed) "
        "VALUES (99999, 'Concurrent User', 'conc@test.com', 'hash', 0, 'Traveler', "
        "'en', 0, 0, 1, 0, 0)"
    )
    # Published lesson
    cur.execute(
        "INSERT INTO lessons (id, unit_id, sequence, title, subtitle, exercise_type, "
        "xp_reward, word_count, required_level, is_published, is_checkpoint, "
        "vocabulary_verified) "
        "VALUES ('ct_lesson', 99999, 1, 'Test Lesson', 'Test', 'matchWords', "
        "20, 4, 1, true, false, true)"
    )
    # Exercise (one matchWords exercise)
    cur.execute(
        "INSERT INTO exercises (id, lesson_id, exercise_type, instruction, "
        "sequence, options, pairs, correct_answer_config, newari_script, romanization) "
        "VALUES ('ct_ex1', 'ct_lesson', 'matchWords', 'Match', 1, "
        "'[{\"id\":\"d1\",\"text\":\"नमस्ते\",\"is_devanagari\":true},"
        "{\"id\":\"e1\",\"text\":\"Hello\"}]', "
        "'{\"d1\":\"e1\"}', '{\"pairs\":{\"d1\":\"e1\"}}', 'नमस्ते', 'namaste')"
    )
    conn.commit()
    cur.close()
    return 99999, "ct_lesson", 20


def test_partial_unique_index_prevents_duplicate_correct():
    """Only one fully-correct attempt per user+lesson can exist."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        user_id, lesson_id, xp_reward = setup_user_and_lesson(conn)

        # Insert first correct attempt
        cur.execute(
            "INSERT INTO attempts (user_id, lesson_id, attempt_number, idempotency_key, "
            "is_correct, correct_answers, total_questions, xp_earned) "
            "VALUES (%s, %s, 1, 'key-1', true, 1, 1, %s)",
            (user_id, lesson_id, xp_reward),
        )
        conn.commit()

        # Attempt to insert a second correct attempt for same user+lesson
        try:
            cur.execute(
                "INSERT INTO attempts (user_id, lesson_id, attempt_number, idempotency_key, "
                "is_correct, correct_answers, total_questions, xp_earned) "
                "VALUES (%s, %s, 2, 'key-2', true, 1, 1, %s)",
                (user_id, lesson_id, xp_reward),
            )
            conn.commit()
            print("FAIL: Second correct attempt was NOT blocked by partial unique index")
            return False
        except psycopg.errors.UniqueViolation:
            conn.rollback()
            print("PASS: Second correct attempt blocked by partial unique index")

        # Verify XP only awarded once
        cur.execute(
            "SELECT SUM(xp_earned) FROM attempts WHERE user_id=%s AND lesson_id=%s",
            (user_id, lesson_id),
        )
        total_xp = cur.fetchone()[0]
        if total_xp == xp_reward:
            print(f"PASS: Total XP awarded = {total_xp} (expected {xp_reward})")
        else:
            print(f"FAIL: Total XP awarded = {total_xp} (expected {xp_reward})")
            return False

        cur.close()
        return True
    finally:
        conn.close()


def test_idempotency_key_scoped_to_user():
    """Same idempotency key can be used by different users (scoped constraint)."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        user_id, lesson_id, xp_reward = setup_user_and_lesson(conn)

        # Create a second user
        cur.execute("DELETE FROM users WHERE id = 99998")
        cur.execute(
            "INSERT INTO users (id, name, email, password_hash, hero_index, hero_class_name, "
            "language_id, streak, xp, level, words_found, lessons_completed) "
            "VALUES (99998, 'Concurrent User 2', 'conc2@test.com', 'hash', 0, 'Traveler', "
            "'en', 0, 0, 1, 0, 0)"
        )
        conn.commit()

        # User 99999 uses key 'shared-key' for correct attempt
        cur.execute(
            "INSERT INTO attempts (user_id, lesson_id, attempt_number, idempotency_key, "
            "is_correct, correct_answers, total_questions, xp_earned) "
            "VALUES (%s, %s, 1, 'shared-key', true, 1, 1, %s)",
            (user_id, lesson_id, xp_reward),
        )
        conn.commit()

        # User 99998 uses SAME key 'shared-key' - should succeed (scoped to user)
        try:
            cur.execute(
                "INSERT INTO attempts (user_id, lesson_id, attempt_number, idempotency_key, "
                "is_correct, correct_answers, total_questions, xp_earned) "
                "VALUES (%s, %s, 1, 'shared-key', true, 1, 1, %s)",
                (99998, lesson_id, xp_reward),
            )
            conn.commit()
            print("PASS: Same idempotency key allowed for different user (scoped)")
        except psycopg.errors.UniqueViolation:
            conn.rollback()
            print("FAIL: Same idempotency key rejected for different user (not scoped)")
            return False

        # Same user reusing same key should fail
        try:
            cur.execute(
                "INSERT INTO attempts (user_id, lesson_id, attempt_number, idempotency_key, "
                "is_correct, correct_answers, total_questions, xp_earned) "
                "VALUES (%s, %s, 2, 'shared-key', true, 1, 1, %s)",
                (user_id, lesson_id, xp_reward),
            )
            conn.commit()
            print("FAIL: Same user reusing idempotency key was NOT blocked")
            return False
        except psycopg.errors.UniqueViolation:
            conn.rollback()
            print("PASS: Same user reusing idempotency key blocked")

        cur.close()
        return True
    finally:
        conn.close()


def test_legitimate_retry_still_possible():
    """Incorrect attempts don't block future correct attempts (constraint allows it)."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        user_id, lesson_id, xp_reward = setup_user_and_lesson(conn)

        # First attempt: incorrect - should succeed (is_correct=false, not blocked by partial index)
        cur.execute(
            "INSERT INTO attempts (user_id, lesson_id, attempt_number, idempotency_key, "
            "is_correct, correct_answers, total_questions, xp_earned) "
            "VALUES (%s, %s, 1, 'retry-key-1', false, 0, 1, 0)",
            (user_id, lesson_id),
        )
        conn.commit()
        print("PASS: Incorrect attempt inserted (not blocked by partial unique index)")

        # Second attempt: correct - should also succeed (first correct for this user+lesson)
        cur.execute(
            "INSERT INTO attempts (user_id, lesson_id, attempt_number, idempotency_key, "
            "is_correct, correct_answers, total_questions, xp_earned) "
            "VALUES (%s, %s, 2, 'retry-key-2', true, 1, 1, %s)",
            (user_id, lesson_id, xp_reward),
        )
        conn.commit()
        print("PASS: Correct attempt after incorrect retry inserted successfully")

        # Verify both attempts exist
        cur.execute(
            "SELECT attempt_number, is_correct, xp_earned FROM attempts "
            "WHERE user_id=%s AND lesson_id=%s ORDER BY attempt_number",
            (user_id, lesson_id),
        )
        rows = cur.fetchall()
        if len(rows) == 2 and rows[0][1] == False and rows[1][1] == True:
            print("PASS: Both attempts preserved with correct ordering")
        else:
            print(f"FAIL: Unexpected attempt rows: {rows}")
            return False

        cur.close()
        return True
    finally:
        conn.close()


def main():
    results = []
    results.append(("Partial unique index prevents duplicate correct",
                    test_partial_unique_index_prevents_duplicate_correct()))
    results.append(("Idempotency key scoped to user",
                    test_idempotency_key_scoped_to_user()))
    results.append(("Legitimate retry still possible",
                    test_legitimate_retry_still_possible()))

    print("\n=== Results ===")
    all_pass = True
    for name, passed in results:
        status = "PASS" if passed else "FAIL"
        print(f"  {status}: {name}")
        if not passed:
            all_pass = False

    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
