# Claude Code prompt: regulars, conversations and online orders

## Before you paste

1. Export each character bible (Stitches, Cheddar, Mabel) as Markdown.
2. Put the three files in your Godot project at `design/characters/`, named `stitches.md`, `cheddar.md`, and `mabel.md`.
3. Commit them to git.
4. Paste everything below the line into Claude Code from your project folder.

---

I'm continuing my cozy 3D restaurant game in Godot 4 (GDScript). The vertical slice already works: player movement, camera, customers, ordering, one cooking minigame, serving, cleaning, end-of-day screen, and save/load.

Now I'm adding the heart of the game: three regular animal customers with deep, branching relationships, plus online delivery orders that fill the rest of the day.

The full design for each character is in `design/characters/stitches.md`, `cheddar.md`, and `mabel.md`. Read all three before writing any code. They are the source of truth for every line of dialogue, every number, and every trigger. If something in this prompt and those files disagree, follow the files and tell me.

IMPORTANT: Use Godot 4 syntax and APIs only (CharacterBody3D, @export, @onready, signal.connect(), await). Do not use Godot 3 syntax. Tell me if you're unsure about an API.

## Rules

- All dialogue, choices, numbers, and triggers live in data files (JSON), never hard-coded in scripts. One file per character, plus shared files for gossip and scenes.
- Build one shared system that works for every character. Adding a fourth character later should only mean adding a data file.
- Keep game logic separate from UI and input. Keep using `player_index` for input.
- Work in small steps. After each step, tell me exactly how to run it and what I should see, then wait for me to test before continuing.
- Commit to git after each working step.
- Prefer simple, readable code. Add a short comment at the top of each script explaining what it does.
- The menu doesn't exist yet. Use placeholder dish ids (e.g. `dish_soup`, `dish_cheese`, `dish_fancy`) and the tokens from the docs (`[dish]`, `[name]`, `[nickname]`, `[last_rude_line]`, etc.). Make tokens easy to swap later.

## What to build, in order

1. **Debug panel (build this first).** A toggleable panel to: set any regular's relationship, skip real days (fake the date), force a regular to visit today, trigger any scene, and reset a character. Every later step depends on this for testing.

2. **Character data and relationship model.** For each regular: the fields from the original plan, plus: relationship (-100 to 100), stage (derived from relationship), rude_streak, last_rude_line, friends, pending_gossip, referral_only, referred_by, big_moment_done (or gift_given), seen_lines, and character-specific fields (Cheddar's nickname and player_favorite, Mabel's story progress and wrong-name state). Tone reaction values per stage come from each doc's tone table.

3. **Daily schedule.** Only 2 or 3 regulars visit per day. Pick them weighted toward whoever hasn't visited in longest. Characters at Withdrawn or Gone never visit in person. Referral-only characters never appear unless referred.

4. **Visit flow as a state machine:** arrive → arrival line → ordering conversation → (optional "What do you recommend?" / "Surprise me" flow) → cook → serve line → eating phase → leave → clean. The eating phase lasts about 60–90 seconds of real time. During it, the player can walk up once for an eating chat. The customer stays seated and visibly eating the whole time.

5. **Conversation system.** A dialogue box with the character's line and 2 to 4 response buttons, each tagged with a tone (warm, playful, straight, rude). Rude is always the last button. The game picks the best-matching line using conditions: stage, first visit, days away (3+ real days), last service quality, flags, and seen_lines (avoid repeats). Applying a choice changes relationship using the tone table, unless the line overrides the value.

6. **Rude rules.** Relationship can't go below 0 unless rude_streak is 3 or more. Any non-rude choice resets the streak. One visit can drop at most one stage. Save the exact rude line the player chose as last_rude_line.

7. **Names.** knows_player_name unlocks at the stage in each doc. Also build Cheddar's nickname picker and Mabel's wrong-name test and reveal.

8. **Online delivery orders.** A timer creates delivery orders that fill the gaps between regulars' visits. A delivery character (placeholder capsule) arrives, picks up the finished dish, and leaves. Make timers forgiving, so stopping to chat with a regular is never punished. Delivery timers should pause or slow while the player is in a conversation. Withdrawn characters' orders show up here with their name and their note from the docs. Players can tuck a note into these bags (the redemption hook).

9. **Gossip and friendships.** Friend lists, including friendships that form during play (Stitches and Mabel at 50+, Stitches and Cheddar at 50+). Queue gossip when a stage boundary is crossed or a rude line is chosen. The friend brings it up once on their next visit, quoting last_rude_line when relevant. Choices in gossip conversations affect both characters, as each doc's tables describe.

10. **Gone and redemption.** The goodbye note/letter, a "Write a letter" option at the counter (the letter's choices are checked against what each character values), "ask a friend" options, and each character's return scene. They return at relationship 0. A second fall to Gone is permanent.

11. **Big moment scenes.** A simple scripted scene player driven by data: camera move, dimmed lights or music change, lines, choices. Build Stitches' gift scene, Cheddar's cooking-for-you scene, and Mabel's storm soup scene with their triggers and one-time flags. Rewards can be flags for now (apron, sign decoration, bell, unlocked dish). Mabel's co-cooking minigame can't fail.

12. **Save/load.** Add every new field, the daily schedule state, pending gossip, and letter/scene flags to the save file. Test by closing the game, faking the date forward with the debug panel, and reopening.

Start with steps 1 and 2 only, then stop and let me test.
