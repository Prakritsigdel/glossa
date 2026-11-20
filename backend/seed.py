from sqlalchemy import select

from app.database import Base, SessionLocal, engine
from app.models import Exercise, Lesson

LESSONS = [
    ("lesson_1", "Rice and Bread", "Match · 4 words", "matchWords", 20, 4, 1),
    ("lesson_2", "Around the House", "Fill in the blank · +20 XP", "fillBlank", 20, 4, 3),
    ("lesson_3", "Fruits and Veggies", "Picture to word", "pictureToWord", 20, 4, 4),
    ("lesson_4", "Grandma's Kitchen", "Word to picture", "wordToPicture", 20, 4, 5),
    ("lesson_5", "Family at Home", "Audio lesson", "matchWords", 25, 5, 6),
    ("lesson_6", "Festival Feast", "Speak and record", "fillBlank", 30, 6, 7),
]
EXERCISES = [
    dict(id="mw_1", lesson_id="lesson_1", exercise_type="matchWords", instruction="Match the words", options=[
        {"id":"mw_d1","text":"माँ","is_devanagari":True}, {"id":"mw_e1","text":"Mother"},
        {"id":"mw_d2","text":"ल","is_devanagari":True}, {"id":"mw_e2","text":"House"},
        {"id":"mw_d3","text":"छें","is_devanagari":True}, {"id":"mw_e3","text":"Water"},
        {"id":"mw_d4","text":"बजि","is_devanagari":True}, {"id":"mw_e4","text":"Beaten rice"}],
         pairs={"mw_d1":"mw_e1","mw_d2":"mw_e2","mw_d3":"mw_e3","mw_d4":"mw_e4"}),
    dict(id="fb_1", lesson_id="lesson_2", exercise_type="fillBlank", instruction="Fill in the blank", prompt="दौ ___", prompt_hint="Yogurt and beaten rice", options=[
        {"id":"fb_a","text":"बजि","is_devanagari":True},{"id":"fb_b","text":"ल","is_devanagari":True},{"id":"fb_c","text":"छें","is_devanagari":True}], answer_id="fb_a"),
    dict(id="fb_2", lesson_id="lesson_2", exercise_type="fillBlank", instruction="Fill in the blank", prompt="___ खा", prompt_hint="Eating at home", options=[
        {"id":"fb2_a","text":"ल","is_devanagari":True},{"id":"fb2_b","text":"माँ","is_devanagari":True},{"id":"fb2_c","text":"छें","is_devanagari":True}], answer_id="fb2_a"),
    dict(id="ptw_1", lesson_id="lesson_3", exercise_type="pictureToWord", instruction="Name the picture", prompt="What is this called?", image_key="bowl", options=[
        {"id":"ptw_a","text":"बजि","is_devanagari":True},{"id":"ptw_b","text":"छें","is_devanagari":True},{"id":"ptw_c","text":"ल","is_devanagari":True},{"id":"ptw_d","text":"माँ","is_devanagari":True}], answer_id="ptw_a"),
    dict(id="wtp_1", lesson_id="lesson_4", exercise_type="wordToPicture", instruction="Pick the picture", prompt="Which picture is this?", options=[
        {"id":"wtp_a","text":"House","image_key":"house"},{"id":"wtp_b","text":"Water","image_key":"droplet"},{"id":"wtp_c","text":"Bowl","image_key":"bowl"},{"id":"wtp_d","text":"Person","image_key":"person"}], answer_id="wtp_a"),
    dict(id="fb5_1", lesson_id="lesson_5", exercise_type="fillBlank", instruction="Fill in the blank", prompt="___ खा", prompt_hint="Eating at home", options=[
        {"id":"fb5_a","text":"ल","is_devanagari":True},{"id":"fb5_b","text":"माँ","is_devanagari":True},{"id":"fb5_c","text":"छें","is_devanagari":True}], answer_id="fb5_a"),
    dict(id="fb6_1", lesson_id="lesson_6", exercise_type="fillBlank", instruction="Fill in the blank", prompt="दौ ___", prompt_hint="Yogurt and beaten rice", options=[
        {"id":"fb6_a","text":"बजि","is_devanagari":True},{"id":"fb6_b","text":"ल","is_devanagari":True},{"id":"fb6_c","text":"छें","is_devanagari":True}], answer_id="fb6_a"),
]

Base.metadata.create_all(bind=engine)
with SessionLocal() as db:
    for lesson_data in LESSONS:
        if db.get(Lesson, lesson_data[0]) is None:
            db.add(Lesson(id=lesson_data[0], title=lesson_data[1], subtitle=lesson_data[2], exercise_type=lesson_data[3], xp_reward=lesson_data[4], word_count=lesson_data[5], required_level=lesson_data[6]))
    db.commit()
    for exercise_data in EXERCISES:
        if db.get(Exercise, exercise_data["id"]) is None:
            db.add(Exercise(**exercise_data))
    db.commit()
