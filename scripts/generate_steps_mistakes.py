#!/usr/bin/env python3
"""Generate `commonMistakesJa/En` (always) and `stepTextJaRaw/EnRaw` (only when
empty) for every exercise in WorkoutKit/Resources/exercises_seed.json.

Strategy:
  1. For each record, classify into a category by slug-keyword first,
     then fall back to typeRaw + primaryMuscleRaw + mechanicsTypeRaw.
  2. Lookup category-specific (steps_ja, steps_en, mistakes_ja, mistakes_en)
     templates and inject into the record.
  3. `commonMistakesJa/En` are stored as newline-separated strings (cautions
     pattern). `stepTextJaRaw/EnRaw` are JSON-encoded string arrays
     (existing pattern).
  4. Existing curated step data is preserved — we only fill the gap.

Idempotent: re-running with no changes is a no-op.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "WorkoutKit" / "Resources" / "exercises_seed.json"


# ---------------------------------------------------------------------------
# Category templates — each entry is (steps_ja, steps_en, mistakes_ja,
# mistakes_en). Steps and mistakes are small lists (3–4 items typically).
# ---------------------------------------------------------------------------

TEMPLATES: dict[str, tuple[list[str], list[str], list[str], list[str]]] = {

    # --- Squat family -----------------------------------------------------
    "squat": (
        ["立位で足を肩幅に開く", "腰を引きつつ膝と股関節を曲げて下げる",
         "太ももが床と平行になるまで沈む", "踵で床を押し返して立ち上がる"],
        ["Stand with feet shoulder-width apart",
         "Sit hips back and bend knees together",
         "Descend until thighs are parallel to the floor",
         "Drive through your heels to stand back up"],
        ["膝が内側に入る", "踵が浮く", "背中が丸まる"],
        ["Knees cave inward", "Heels lift off the floor", "Back rounds at the bottom"],
    ),
    "split-squat": (
        ["前後に大きくスタンスを取る", "後ろ足の膝を床近くまで下ろす",
         "前足の踵で押して立ち上がる", "左右セットを切り替える"],
        ["Take a long staggered stance",
         "Lower the back knee toward the floor",
         "Drive through the front heel to stand",
         "Switch sides between sets"],
        ["前膝が内に入る", "後ろ足の膝が床に当たる", "上体が前のめりになる"],
        ["Front knee caves in", "Back knee crashes down", "Torso pitches forward"],
    ),
    "lunge": (
        ["立位から大きく一歩前へ踏み出す", "後ろ脚の膝が床に近づくまで沈む",
         "前脚の踵で押して元の姿勢に戻る", "左右交互に繰り返す"],
        ["Step forward into a long stride",
         "Lower until the back knee nearly touches the floor",
         "Drive through the front heel to return",
         "Alternate legs each rep"],
        ["前膝が内側に入る", "上体が前傾し過ぎる", "歩幅が短く膝が前に出る"],
        ["Front knee caves in", "Torso leans too far forward",
         "Stride too short — knee drifts past toes"],
    ),
    "step-up": (
        ["ボックスの前に立つ", "片足をボックスに乗せ、踵で押し上げる",
         "上で一瞬静止", "コントロールして降りる"],
        ["Stand in front of the box",
         "Plant one foot and drive through the heel",
         "Pause briefly at the top",
         "Lower under control"],
        ["反対脚で蹴って勢いをつける", "体が前傾しすぎる", "降りる動作が雑"],
        ["Push off with the rear leg", "Torso pitches too far forward",
         "Lowering is rushed"],
    ),

    # --- Deadlift family --------------------------------------------------
    "deadlift": (
        ["足は肩幅、バーを足の中央に置く",
         "ヒップヒンジで上体を倒しバーを握る",
         "背中をまっすぐ保ち、脚で床を押し返す",
         "立ち上がりロックアウト"],
        ["Feet shoulder-width, bar over mid-foot",
         "Hinge at the hips and grip the bar",
         "Brace, push the floor away with the legs",
         "Stand tall and lock out"],
        ["腰が丸まる", "バーが体から離れる", "膝が先に伸びてバーが置き去り"],
        ["Lower back rounds", "Bar drifts away from the body",
         "Knees lock out before bar leaves the floor"],
    ),
    "romanian-deadlift": (
        ["バーを腿前で持って立つ", "膝はわずかに曲げ、股関節を後ろに引く",
         "ハムが伸びる位置まで下ろす", "股関節を前に押し戻して立つ"],
        ["Stand holding the bar at the thighs",
         "Slight knee bend, hinge hips back",
         "Lower until the hamstrings stretch",
         "Drive hips forward to stand"],
        ["膝を曲げ過ぎる", "腰が丸まる", "バーが前方に離れる"],
        ["Knees bend too much", "Lower back rounds",
         "Bar drifts forward away from the legs"],
    ),

    # --- Press family -----------------------------------------------------
    "bench-press": (
        ["ベンチに仰向けで肩甲骨を寄せる", "バーを肩幅より少し広く握る",
         "胸の中央までバーを下ろす", "踏ん張りつつ押し上げる"],
        ["Lie back, retract the shoulder blades",
         "Grip the bar slightly wider than shoulders",
         "Lower bar to mid-chest under control",
         "Press back up while bracing"],
        ["肩がすくむ", "腰が大きく反る", "肘が真横に開く"],
        ["Shoulders shrug toward the ears",
         "Lower back overarches", "Elbows flare out at 90°"],
    ),
    "incline-press": (
        ["インクラインベンチに座る", "バー/ダンベルを胸の上部に下ろす",
         "肘を脇から45度で押し上げる", "ロックアウトの直前で止める"],
        ["Set up on an incline bench",
         "Lower the load to the upper chest",
         "Press up with elbows at ~45°",
         "Stop just shy of full lockout"],
        ["腰が反って胸が浮く", "肩がすくむ", "肘が真横に開く"],
        ["Lower back arches off the bench",
         "Shoulders shrug", "Elbows flare out at 90°"],
    ),
    "decline-press": (
        ["デクラインベンチに固定", "バーを胸下部に下ろす",
         "押し上げ、ロック直前で止める", "コントロールして繰り返す"],
        ["Lock into the decline bench",
         "Lower bar to the lower chest",
         "Press up, stop short of lockout",
         "Repeat under control"],
        ["バーが顔に向かう", "肩が浮く", "下ろしが速い"],
        ["Bar tracks toward the face",
         "Shoulders lift off the bench",
         "Lowering is rushed"],
    ),
    "shoulder-press": (
        ["バー/ダンベルを肩の前で構える", "体幹を固めて頭上に押し上げる",
         "肘を伸ばし切らず止める", "コントロールして肩へ戻す"],
        ["Hold the load at shoulder level",
         "Brace the core and press overhead",
         "Stop just shy of lockout",
         "Lower back to the shoulders"],
        ["腰が大きく反る", "肘が前に出る", "首がすくむ"],
        ["Lower back overarches", "Elbows drift forward",
         "Shoulders shrug into the neck"],
    ),
    "push-press": (
        ["立位でバーを肩で構える", "浅く膝を曲げてディップ",
         "脚の力で爆発的に押し上げる", "コントロールして下ろす"],
        ["Stand with bar racked on the shoulders",
         "Quick quarter-dip with the legs",
         "Drive up explosively to lockout",
         "Lower under control"],
        ["ディップが深すぎる", "脚の力を使わず腕だけ", "腰が反る"],
        ["Dip too deep", "Press with arms only — no leg drive",
         "Lower back overextends"],
    ),

    # --- Pull family ------------------------------------------------------
    "pull-up": (
        ["バーを肩幅より広く順手で握る", "肩甲骨を下げて寄せる",
         "胸をバーに近づけるまで引く", "コントロールして下ろす"],
        ["Grip the bar slightly wider than shoulders",
         "Depress and retract the shoulder blades",
         "Pull until chest meets the bar",
         "Lower with control"],
        ["キッピングで反動を使う", "肘が伸びきらない", "肩がすくむ"],
        ["Kipping with body swing",
         "Failing to lock out at the bottom",
         "Shoulders shrug toward the ears"],
    ),
    "chin-up": (
        ["バーを肩幅で逆手に握る", "肩甲骨を寄せ下げる",
         "顎がバーを越えるまで引く", "コントロールして下ろす"],
        ["Grip the bar shoulder-width with palms toward you",
         "Set the shoulder blades down and back",
         "Pull until chin clears the bar",
         "Lower with control"],
        ["反動で蹴り上げる", "肘が伸びきらない", "首が前に出る"],
        ["Kipping with leg drive",
         "Skipping the dead-hang lockout",
         "Neck cranes forward"],
    ),
    "inverted-row": (
        ["バーの下に体を入れて握る", "踵だけ床につけ体を一直線に",
         "胸をバーに近づけて引く", "ゆっくり下ろす"],
        ["Set up under the bar and grip",
         "Heels on the floor, body straight",
         "Pull chest to the bar",
         "Lower under control"],
        ["お尻が落ちる", "肩がすくむ", "引きが浅い"],
        ["Hips sag", "Shoulders shrug", "Pull is too shallow"],
    ),
    "row": (
        ["ヒップヒンジで上体を倒す", "肩甲骨を寄せながら肘を後ろに引く",
         "ピーク収縮で1秒静止", "コントロールして戻す"],
        ["Hinge forward at the hips",
         "Pull elbows back, retracting the shoulder blades",
         "Pause one second at peak contraction",
         "Lower under control"],
        ["肩がすくむ", "腰が反る", "引きが浅い"],
        ["Shoulders shrug",
         "Lower back overarches",
         "Pull is too shallow"],
    ),
    "pulldown": (
        ["バーを肩幅程度で握る", "肩甲骨を下げ、肘を体側へ引く",
         "胸の上部までバーを下ろす", "コントロールして戻す"],
        ["Grip the bar around shoulder-width",
         "Depress shoulders, pull elbows toward the body",
         "Bring the bar to the upper chest",
         "Return under control"],
        ["体を反らせ過ぎる", "首を前に出して引く", "肘が後ろに引けていない"],
        ["Leans back excessively",
         "Cranes neck forward to pull",
         "Elbows fail to track behind the body"],
    ),
    "face-pull": (
        ["ロープを顔の高さで構える", "肩甲骨を寄せながら顔へ引く",
         "外旋して肘を高く保つ", "コントロールして戻す"],
        ["Set the rope at face height",
         "Pull toward the face, retracting blades",
         "Externally rotate, elbows high",
         "Return slowly"],
        ["肘が下がる", "反動で引く", "肩がすくむ"],
        ["Elbows drop low", "Body english is used to pull",
         "Shoulders shrug into the neck"],
    ),

    # --- Curls / extensions / raises -------------------------------------
    "curl": (
        ["ダンベル/バーを脚の前で構える", "肘を固定し前腕だけで巻き上げる",
         "ピーク収縮で1秒静止", "コントロールして下ろす"],
        ["Hold the load at the thighs",
         "Curl with the forearms only — elbows fixed",
         "Pause one second at the top",
         "Lower under control"],
        ["肘が前後に動く", "上体を反らせて反動", "下ろしが速い"],
        ["Elbows drift forward and back",
         "Body english from the torso",
         "Lowering is rushed"],
    ),
    "tricep-extension": (
        ["重りを構え、肘を体側に固定", "肘から先で伸ばし切る",
         "1秒静止して収縮", "コントロールして戻す"],
        ["Brace, elbows pinned to the sides",
         "Extend through the elbow only",
         "Pause one second at lockout",
         "Lower under control"],
        ["肘が外に開く", "肩が前に出る", "戻しが速い"],
        ["Elbows flare out", "Shoulders dump forward",
         "Eccentric is rushed"],
    ),
    "skull-crusher": (
        ["仰向けでバーを構える", "肘を固定し額の上まで下ろす",
         "肘で押して伸ばし切る", "コントロールして繰り返す"],
        ["Lie back holding the bar",
         "Lower toward the forehead, elbows fixed",
         "Press up to lockout",
         "Repeat under control"],
        ["肘が外に開く", "肘の位置が前後に動く", "下ろしが速い"],
        ["Elbows flare out",
         "Elbows drift forward and back",
         "Eccentric is rushed"],
    ),
    "lateral-raise": (
        ["ダンベルを腿の横で構える", "肘を軽く曲げ肩の高さまで上げる",
         "ピーク収縮で1秒静止", "コントロールして下ろす"],
        ["Hold dumbbells at your sides",
         "Raise to shoulder height with a slight elbow bend",
         "Pause one second at the top",
         "Lower under control"],
        ["肩がすくむ", "肘が下がる", "反動で持ち上げる"],
        ["Shoulders shrug into the neck",
         "Elbows drop below the wrists",
         "Body english is used"],
    ),
    "front-raise": (
        ["ダンベルを腿前で構える", "肘を軽く曲げ肩の高さまで前に上げる",
         "1秒静止", "コントロールして下ろす"],
        ["Hold dumbbells in front of the thighs",
         "Raise to shoulder height with a slight elbow bend",
         "Pause one second",
         "Lower under control"],
        ["反動を使う", "上げ過ぎて僧帽が働く", "腰を反らせる"],
        ["Body english is used",
         "Raise too high — traps take over",
         "Lower back overarches"],
    ),
    "rear-delt-fly": (
        ["前傾姿勢で構える", "肘を軽く曲げ肩の高さまで開く",
         "肩甲骨を寄せ過ぎず止める", "コントロールして戻す"],
        ["Hinge into a bent-over position",
         "Open arms to shoulder height with a slight elbow bend",
         "Stop short of pinching the blades",
         "Return under control"],
        ["体を反らせて反動", "肘が下がる", "首が前に出る"],
        ["Body english from the torso",
         "Elbows drop below shoulders",
         "Neck cranes forward"],
    ),
    "shrug": (
        ["バー/ダンベルを腿の横で構える", "肩を真上にすくめる",
         "ピーク収縮で1秒静止", "コントロールして下ろす"],
        ["Hold the load at your sides",
         "Shrug straight up",
         "Pause one second at the top",
         "Lower under control"],
        ["肘が曲がる", "肩を回す", "下ろしが速い"],
        ["Elbows bend during the lift",
         "Shoulders rotate instead of elevating",
         "Eccentric is rushed"],
    ),

    # --- Fly / chest accessories -----------------------------------------
    "fly": (
        ["ダンベル/ケーブルを構える", "肘を軽く曲げて開く",
         "胸の上で閉じピーク収縮", "コントロールして戻す"],
        ["Set up holding dumbbells or cables",
         "Open arms with a slight elbow bend",
         "Close at the centre — peak contraction",
         "Return under control"],
        ["肘が伸びきる", "可動域が浅い", "肩がすくむ"],
        ["Elbows lock out", "Range of motion is shallow",
         "Shoulders shrug"],
    ),
    "pec-deck": (
        ["シートに座り胸を張る", "両肘でパッドを押し中央へ",
         "1秒静止", "コントロールして戻す"],
        ["Sit and brace the chest",
         "Press the pads together at the centre",
         "Hold one second", "Return under control"],
        ["反動で閉じる", "腰を反らせる", "戻しが速い"],
        ["Body english to close",
         "Lower back arches",
         "Eccentric is rushed"],
    ),

    # --- Plank / core ----------------------------------------------------
    "plank": (
        ["うつ伏せで肘を肩の真下に置く",
         "つま先と前腕で体を支える", "頭から踵まで一直線にキープ",
         "目標時間まで保つ"],
        ["Lie face-down, elbows under the shoulders",
         "Lift onto forearms and toes",
         "Hold a straight line from head to heels",
         "Hold for the target time"],
        ["お尻が落ちる", "お尻が上がり過ぎる", "首が反る"],
        ["Hips sag below the line",
         "Hips pike up too high",
         "Neck cranes upward"],
    ),
    "side-plank": (
        ["横向きで肘を肩の真下に置く",
         "腰を持ち上げ体を一直線に", "目線は前方",
         "目標時間まで保つ"],
        ["Lie on your side, elbow under the shoulder",
         "Lift hips into a straight line",
         "Eyes forward",
         "Hold for the target time"],
        ["腰が下がる", "肩がすくむ", "首が前に出る"],
        ["Hips drop", "Shoulder shrugs",
         "Neck cranes forward"],
    ),
    "crunch": (
        ["仰向けで膝を立てる", "肩甲骨が床から離れるまで巻き上げる",
         "1秒静止", "コントロールして戻す"],
        ["Lie back with knees bent",
         "Curl up until the shoulder blades lift",
         "Hold one second",
         "Lower under control"],
        ["首を手で引っ張る", "反動で起き上がる", "腰が浮く"],
        ["Hands pull on the neck",
         "Body english to come up",
         "Lower back lifts off the floor"],
    ),
    "russian-twist": (
        ["座位で膝を立て体を後ろに倒す",
         "重りを左右に振り体幹で回旋",
         "テンポを保つ", "目標回数まで続ける"],
        ["Sit and lean back with knees bent",
         "Rotate the torso side to side",
         "Keep a steady tempo",
         "Continue for target reps"],
        ["肩で振って体幹を使わない", "背中が丸まる", "脚の動きが大きい"],
        ["Rotates from the shoulders, not the core",
         "Back rounds excessively",
         "Legs swing too much"],
    ),
    "ab-wheel": (
        ["膝立ちでホイールを握る", "腹圧を保ち前へ転がす",
         "限界点で1秒静止", "腹筋で戻す"],
        ["Kneel and grip the wheel",
         "Roll forward keeping core braced",
         "Pause one second at full extension",
         "Pull back with the abs"],
        ["腰が反る", "戻しが速く反動を使う", "肩で押す"],
        ["Lower back overextends",
         "Pulled back by momentum",
         "Pushes from the shoulders"],
    ),
    "side-bend": (
        ["立位で重りを片手に持つ", "重りの側へ体を真横に倒す",
         "反対側を絞るように戻す", "左右セット切り替え"],
        ["Stand with weight in one hand",
         "Bend straight to the loaded side",
         "Squeeze the opposite obliques to return",
         "Switch sides between sets"],
        ["前後に体が傾く", "可動域が狭い", "反動を使う"],
        ["Body tips forward or back",
         "Range of motion is too small",
         "Body english is used"],
    ),
    "woodchopper": (
        ["ケーブルを高位置から構える", "体幹を回旋して斜め下へ引く",
         "コントロールして戻す", "左右セット切り替え"],
        ["Set the cable high",
         "Rotate the torso and chop diagonally down",
         "Return under control",
         "Switch sides between sets"],
        ["腕で引く", "腰だけで回す", "戻しが速い"],
        ["Pulls with the arms only",
         "Rotates only at the lower back",
         "Eccentric is rushed"],
    ),

    # --- Hip / glute -----------------------------------------------------
    "hip-thrust": (
        ["肩甲骨をベンチに乗せ膝を立てる",
         "バー/重りを骨盤に固定",
         "ヒップを上げ体を一直線に", "1秒静止して下ろす"],
        ["Upper back on a bench, knees bent",
         "Brace a bar across the hips",
         "Drive the hips up to lockout",
         "Pause then lower"],
        ["腰が反って肋骨が開く", "顎が上がる", "ロックアウトが浅い"],
        ["Lower back overarches and ribs flare",
         "Chin lifts upward",
         "Hips don't reach lockout"],
    ),
    "glute-bridge": (
        ["仰向けで膝を立てる", "ヒップを上げ体を一直線に",
         "1秒静止", "コントロールして下ろす"],
        ["Lie back with knees bent",
         "Drive hips up into a straight line",
         "Pause one second at the top",
         "Lower under control"],
        ["腰だけで上げる", "顎が上がる", "可動域が浅い"],
        ["Hips driven by lumbar extension",
         "Chin lifts upward",
         "Range of motion is shallow"],
    ),
    "kettlebell-swing": (
        ["ケトルベルを足前に置き構える",
         "ヒップヒンジで間に振り込む",
         "ヒップで前に振り肩の高さへ",
         "戻りはコントロール"],
        ["Stand with the bell in front",
         "Hinge and swing it between the legs",
         "Drive the hips to swing it to shoulder height",
         "Control on the way back"],
        ["スクワットしてしまう", "腕で振り上げる", "腰が反って終わる"],
        ["Squats instead of hinging",
         "Lifts the bell with the arms",
         "Lower back hyperextends at the top"],
    ),

    # --- Legs accessories -------------------------------------------------
    "leg-extension": (
        ["シートに座りパッドに足首を当てる",
         "膝を伸ばし切るまで上げる", "1秒静止",
         "コントロールして戻す"],
        ["Set up with the pad on the shins",
         "Extend the knees fully",
         "Pause one second",
         "Lower under control"],
        ["反動を使う", "戻しが速い", "腰が浮く"],
        ["Body english is used",
         "Eccentric is rushed",
         "Hips lift off the seat"],
    ),
    "leg-curl": (
        ["マシンに足を引っ掛ける", "踵を尻に近づけるまで巻く",
         "1秒静止", "コントロールして戻す"],
        ["Hook the heels into the pad",
         "Curl the heels toward the glutes",
         "Pause one second",
         "Lower under control"],
        ["腰が浮く", "反動を使う", "可動域が浅い"],
        ["Hips lift off the bench",
         "Body english is used",
         "Range of motion is shallow"],
    ),
    "calf-raise": (
        ["立位 / 座位でセット", "可動域いっぱいまで踵を上げる",
         "1秒静止", "ストレッチを感じるまで下ろす"],
        ["Stand or sit in position",
         "Raise the heels through full range",
         "Hold one second",
         "Lower until you feel a calf stretch"],
        ["可動域が狭い", "膝が動く", "反動を使う"],
        ["Range of motion is shallow",
         "Knees flex during the rep",
         "Body english is used"],
    ),
    "hip-abduction": (
        ["マシンにセットし内ももにパッドを当てる",
         "脚を外側に開く", "1秒静止",
         "コントロールして戻す"],
        ["Sit and set the pads on the outer thighs",
         "Press the legs outward",
         "Hold one second",
         "Return under control"],
        ["背中を反らせて勢いをつける", "戻しが速い", "膝が内に入る"],
        ["Leans back to add momentum",
         "Eccentric is rushed",
         "Knees collapse inward"],
    ),
    "back-extension": (
        ["パッドに腰を乗せ前傾する",
         "背筋で体を一直線まで起こす", "1秒静止",
         "コントロールして戻す"],
        ["Set hips on the pad and hinge forward",
         "Extend until the body is straight",
         "Hold one second",
         "Lower under control"],
        ["腰を反らせ過ぎる", "反動で起き上がる", "首が反る"],
        ["Lower back hyperextends",
         "Body english to come up",
         "Neck cranes upward"],
    ),
    "good-morning": (
        ["バーを担いで立つ", "ヒップを引きつつ上体を倒す",
         "ハムが伸びる位置で止める", "ヒップで戻す"],
        ["Stand with the bar racked",
         "Hinge hips back, lowering the torso",
         "Stop where the hamstrings stretch",
         "Drive hips forward to stand"],
        ["背中が丸まる", "膝が深く曲がる", "戻しが速い"],
        ["Lower back rounds",
         "Knees bend too much",
         "Concentric is rushed"],
    ),

    # --- Push-up / dip / mountain climber ---------------------------------
    "push-up": (
        ["手を肩幅より少し広く床につく",
         "頭から踵までを一直線に保つ",
         "胸が床に近づくまで肘を曲げる",
         "床を押し戻して元の姿勢へ"],
        ["Hands slightly wider than shoulders",
         "Keep a straight line from head to heels",
         "Lower until the chest is just above the floor",
         "Press back up to start"],
        ["腰が落ちる", "お尻が高く上がる", "肘が真横に開く"],
        ["Hips sag", "Hips pike up too high",
         "Elbows flare out at 90°"],
    ),
    "dip": (
        ["バーを肩幅で握り体を支える",
         "肘を曲げて肩が肘より下になるまで沈む",
         "押し上げて伸ばし切る", "コントロールして繰り返す"],
        ["Grip parallel bars and support the body",
         "Lower until the shoulders drop below the elbows",
         "Press back up to lockout",
         "Repeat under control"],
        ["肩がすくむ", "沈み過ぎて肩を痛める", "肘が真横に開く"],
        ["Shoulders shrug",
         "Drops too low — shoulder strain",
         "Elbows flare out"],
    ),
    "mountain-climber": (
        ["ハイプランクの姿勢で構える",
         "片膝を胸に近づける", "反対の脚もすばやく入れ替える",
         "テンポを保って続ける"],
        ["Set up in a high plank",
         "Drive one knee toward the chest",
         "Quickly switch legs",
         "Maintain tempo throughout"],
        ["お尻が上下に揺れる", "腰が反る", "手の位置が前にずれる"],
        ["Hips bounce up and down",
         "Lower back overarches",
         "Hands creep forward"],
    ),
    "burpee": (
        ["立位からスクワット姿勢に",
         "両足を後ろに飛ばしプランクへ",
         "プッシュアップして足を戻す",
         "ジャンプして立ち上がる"],
        ["Drop into a squat from standing",
         "Jump the feet back into a plank",
         "Push-up and bring feet back in",
         "Jump up to standing"],
        ["腰が反って着地", "肩がすくむ", "手足の位置が崩れる"],
        ["Lands with lower back overarched",
         "Shoulders shrug",
         "Hand and foot placement breaks down"],
    ),
    "jumping-jacks": (
        ["足を揃え腕を体側で立つ",
         "ジャンプして手足を広げる",
         "ジャンプで戻す", "リズミカルに繰り返す"],
        ["Stand with feet together, arms at sides",
         "Jump feet apart and arms overhead",
         "Jump back to start",
         "Repeat rhythmically"],
        ["膝が伸びきる", "手の動きが小さい", "反動が大き過ぎる"],
        ["Knees lock out hard on landing",
         "Arm motion is too small",
         "Excessive bouncing"],
    ),
    "high-knees": (
        ["その場で立つ", "片膝を腰の高さまで素早く上げる",
         "反対脚も同様にテンポよく", "腕も振って続ける"],
        ["Stand in place",
         "Drive one knee up to hip height",
         "Quickly switch legs",
         "Pump the arms"],
        ["膝の位置が低い", "上体が前傾する", "腕の振りが小さい"],
        ["Knees stay too low",
         "Torso pitches forward",
         "Arm swing is too small"],
    ),
    "butt-kicks": (
        ["その場で立つ", "踵を尻に向かって素早く蹴り上げる",
         "反対脚も同様", "リズミカルに続ける"],
        ["Stand in place",
         "Kick the heel toward the glutes",
         "Switch legs",
         "Continue rhythmically"],
        ["上体が前傾する", "踵が尻に届かない", "腕が振れていない"],
        ["Torso pitches forward",
         "Heel doesn't reach the glutes",
         "Arms aren't engaged"],
    ),

    # --- Stretch / pose ---------------------------------------------------
    "stretch": (
        ["目的の筋肉が伸びる姿勢に入る",
         "20〜30秒ゆっくり呼吸しながらキープ",
         "反対側も同様に", "解除してリラックス"],
        ["Move into the target stretch position",
         "Hold 20–30 seconds with slow breathing",
         "Repeat on the other side",
         "Release and relax"],
        ["反動を使う", "呼吸を止める", "痛みまで伸ばす"],
        ["Bouncing into the stretch",
         "Holding the breath",
         "Pushing into pain"],
    ),

    # --- Warmup default ---------------------------------------------------
    "warmup-default": (
        ["楽な姿勢でスタート", "ゆっくり可動域を広げていく",
         "30〜60秒継続", "呼吸を止めずに終了"],
        ["Start in a relaxed position",
         "Gradually increase range of motion",
         "Continue for 30–60 seconds",
         "Finish without holding the breath"],
        ["反動で大きく動かす", "呼吸を止める", "痛みを我慢する"],
        ["Bouncing through the motion",
         "Holding the breath",
         "Pushing through pain"],
    ),

    # --- Cardio default ---------------------------------------------------
    "cardio-default": (
        ["軽くウォームアップ", "目標心拍/ペースに到達",
         "目標時間 / 距離を維持", "クールダウンして終了"],
        ["Warm up gently",
         "Reach target HR / pace",
         "Maintain for target time/distance",
         "Cool down at the end"],
        ["序盤からペースを上げ過ぎる", "水分補給を忘れる",
         "クールダウンを省く"],
        ["Start too fast",
         "Skipping hydration",
         "Skipping the cool-down"],
    ),

    # --- Generic strength / isolation fallbacks ---------------------------
    "strength-default": (
        ["正しい開始姿勢に入る",
         "2〜3秒かけて重りを下げる",
         "最下点で1秒静止",
         "コントロールしながら戻す"],
        ["Set up in proper position",
         "Lower the load over 2–3 seconds",
         "Pause one second at the bottom",
         "Return under control"],
        ["反動を使う", "呼吸を止める", "フォームが崩れる"],
        ["Body english is used",
         "Holding the breath",
         "Form breaks down"],
    ),
    "isolation-default": (
        ["関節を固定する開始姿勢", "ターゲット筋肉だけで動く",
         "ピーク収縮で1秒静止", "コントロールして戻す"],
        ["Set up isolating the joint",
         "Move only with the target muscle",
         "Pause one second at peak",
         "Lower under control"],
        ["反動を使う", "重さを優先しフォームが崩れる", "可動域が狭い"],
        ["Body english is used",
         "Form breaks down chasing weight",
         "Range of motion is too small"],
    ),
}


# ---------------------------------------------------------------------------
# Classification — map each record to a template key.
# ---------------------------------------------------------------------------

# Slug-keyword rules. First match wins, so put the more specific rules first.
SLUG_RULES: list[tuple[str, str]] = [
    ("romanian-deadlift", "romanian-deadlift"),
    ("split-squat", "split-squat"),
    ("incline", "incline-press"),       # incline-bench / incline-dumbbell
    ("decline", "decline-press"),
    ("bench-press", "bench-press"),
    ("chest-press", "bench-press"),
    ("shoulder-press", "shoulder-press"),
    ("overhead-press", "shoulder-press"),
    ("push-press", "push-press"),
    ("arnold-press", "shoulder-press"),
    ("pec-deck", "pec-deck"),
    ("fly", "fly"),                     # cable-fly / dumbbell-fly
    ("crossover", "fly"),
    ("pullover", "fly"),
    ("face-pull", "face-pull"),
    ("pulldown", "pulldown"),
    ("pull-up", "pull-up"),
    ("chin-up", "chin-up"),
    ("inverted-row", "inverted-row"),
    ("row", "row"),                     # barbell-row, dumbbell-row, t-bar-row, etc.
    ("hip-thrust", "hip-thrust"),
    ("glute-bridge", "glute-bridge"),
    ("hip-abduction", "hip-abduction"),
    ("back-extension", "back-extension"),
    ("hyperextension", "back-extension"),
    ("good-morning", "good-morning"),
    ("kettlebell-swing", "kettlebell-swing"),
    ("step-up", "step-up"),
    ("lunge", "lunge"),
    ("squat", "squat"),                 # any *-squat
    ("deadlift", "deadlift"),
    ("skull-crusher", "skull-crusher"),
    ("tricep", "tricep-extension"),     # rope-pushdown, kickback, etc.
    ("triceps", "tricep-extension"),
    ("extension", "tricep-extension"),  # tricep extension, leg extension handled below
    ("leg-extension", "leg-extension"),
    ("leg-curl", "leg-curl"),
    ("calf-raise", "calf-raise"),
    ("lateral-raise", "lateral-raise"),
    ("front-raise", "front-raise"),
    ("rear-delt", "rear-delt-fly"),
    ("shrug", "shrug"),
    ("curl", "curl"),                   # all curl variants
    ("crunch", "crunch"),
    ("sit-up", "crunch"),
    ("russian-twist", "russian-twist"),
    ("ab-wheel", "ab-wheel"),
    ("rollout", "ab-wheel"),
    ("woodchopper", "woodchopper"),
    ("side-bend", "side-bend"),
    ("side-plank", "side-plank"),
    ("plank", "plank"),
    ("push-up", "push-up"),
    ("pushup", "push-up"),
    ("dip", "dip"),
    ("mountain-climber", "mountain-climber"),
    ("burpee", "burpee"),
    ("jumping-jack", "jumping-jacks"),
    ("high-knee", "high-knees"),
    ("butt-kick", "butt-kicks"),
    ("downward-dog", "stretch"),
    ("childs-pose", "stretch"),
    ("cobra-stretch", "stretch"),
    ("pigeon-pose", "stretch"),
    ("butterfly", "stretch"),
    ("stretch", "stretch"),
    ("pose", "stretch"),
]


def classify(record: dict) -> str:
    """Return the template key for this record."""
    slug = record.get("slug", "").lower()
    type_raw = record.get("typeRaw", "")
    mech = record.get("mechanicsTypeRaw")

    # Slug rules first (most specific)
    for keyword, template_key in SLUG_RULES:
        if keyword in slug:
            return template_key

    # Type-based fallbacks
    if type_raw == "STRETCHING":
        return "stretch"
    if type_raw == "WARMUP":
        return "warmup-default"
    if type_raw == "CARDIO":
        return "cardio-default"

    # Strength / Calisthenics: split by mechanics
    if mech == "ISOLATION":
        return "isolation-default"
    return "strength-default"


# ---------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------

def is_empty_step_array(raw: str | None) -> bool:
    if not raw:
        return True
    s = raw.strip()
    if s in {"", "[]"}:
        return True
    try:
        return len(json.loads(s)) == 0
    except json.JSONDecodeError:
        return True


def main() -> None:
    records = json.loads(SEED_PATH.read_text(encoding="utf-8"))

    steps_filled = 0
    mistakes_filled = 0
    classified_counts: dict[str, int] = {}

    for record in records:
        key = classify(record)
        classified_counts[key] = classified_counts.get(key, 0) + 1
        steps_ja, steps_en, mistakes_ja, mistakes_en = TEMPLATES[key]

        # 1) Always set commonMistakesJa/En (new field).
        new_mistakes_ja = "\n".join(mistakes_ja)
        new_mistakes_en = "\n".join(mistakes_en)
        if record.get("commonMistakesJa") != new_mistakes_ja:
            record["commonMistakesJa"] = new_mistakes_ja
            mistakes_filled += 1
        if record.get("commonMistakesEn") != new_mistakes_en:
            record["commonMistakesEn"] = new_mistakes_en

        # 2) Fill stepTextJaRaw / stepTextEnRaw only when absent / empty.
        if is_empty_step_array(record.get("stepTextJaRaw")):
            record["stepTextJaRaw"] = json.dumps(steps_ja, ensure_ascii=False)
            steps_filled += 1
        if is_empty_step_array(record.get("stepTextEnRaw")):
            record["stepTextEnRaw"] = json.dumps(steps_en, ensure_ascii=False)

    SEED_PATH.write_text(
        json.dumps(records, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"records: {len(records)}")
    print(f"  commonMistakes filled / changed: {mistakes_filled}")
    print(f"  steps filled (was empty):        {steps_filled}")
    print("category distribution:")
    for k, v in sorted(classified_counts.items(), key=lambda kv: -kv[1]):
        print(f"  {k:20s} {v}")


if __name__ == "__main__":
    main()
