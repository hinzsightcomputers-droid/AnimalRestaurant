# Regulars: Missing Lines (Silent Spots)

Nov 7, 2026 · @Alex

## What's missing and the fix

A dialogue check found moments where a regular says nothing. This doc writes the lines for each one.

1. **Mabel and the right drink.** She only reacts when you bring her favourite. If you bring the right drink and it's something else, she says nothing.
2. **Co-op, a chef they haven't met.** Some lines use `[name]`, so the game skips them for a chef whose name that regular hasn't learned yet. When every line for a moment uses `[name]`, the regular goes silent. Solo play is never affected, because regulars learn your name at the door from stage 2.

**The rule from now on:** any moment where every line uses `[name]` also gets at least one name-free line. The game plays a name-free line when the chef's name isn't known, and stays silent only if a moment has no lines at all. Name-free lines can still be warm; they just say "you", "chef" or "dear" instead of a name.

Voices are taken from each regular's character bible: Mabel blunt and rambling, Cheddar a nickname-giving showman, Stitches shy and kind, Zakk the laid-back surfer, Evaroo the deadpan critic.

## Mabel: right drink, not her favourite

Mabel's favourite is black tea. These play when you bring her the drink she ordered and it's something else. They're name-free, so they work for any chef.

| Stage | Lines |
| --- | --- |
| 1. Inspector | "Correct. You'd be amazed how many places can't manage that." / "Right drink. Right temperature. We'll see about the food." |
| 2. Regular | "That's the one. Thank you, dear." / "Good. You listened. Walter never listened when I ordered." |
| 3. Storyteller | "Thank you, dear. Walter used to bring me one of these on slow afternoons. ...Well. It'll keep." |
| 4. Family | "Just right. You run a proper kitchen, dear. I always knew you would." |
| -1. Disappointed | "Thank you." |
| -2. Formal | "Thank you, chef. That will be all." |

## Co-op: food served by a chef they don't know

These play when the chef serving the dish isn't one whose name the regular has learned. Mabel and Cheddar call unknown chefs "chef", the same way they did before they learned your name; Stitches introduces himself.

| Regular | Stage | Good dish (Perfect or Great) | Okay or Burnt |
| --- | --- | --- | --- |
| Zakk | 2. Local | "Whoa, that looks gnarly, dude. Thanks." | "Little crispy, man. No worries." |
| Zakk | 3. Crew | "You cook like the rest of the crew back there, dude. That's a big compliment." | "Bit overdone, man. Still eating every bite." |
| Zakk | 4. Wave buddy | "Dude. Anyone cooking in this kitchen is family to me." | "Wiped out a little, huh? Happens to the best of us, man." |
| Cheddar | 2. Sidekick | "Ooh, a new chef! Fresh talent! This looks great, rookie." | "Okay, new chef, we'll call this one a warm-up round." |
| Cheddar | 3. Real talk | "I don't know you yet, chef, but you're officially on the team." | "Burnt! Classic rookie move. ...Kidding. It's still good." |
| Cheddar | 4. Best friend | "Okay, I don't know you yet, but this? This is best-friend-level food, chef." | (his existing lines already work) |
| Mabel | 2. Regular | "Not bad, chef. Not bad at all. I don't believe we've met." | "A touch heavy on the salt, chef. You'll learn." |
| Mabel | 3. Storyteller | "You've got a good hand, chef. Walter would've hired you on the spot." | "Overdone, chef. It happens. Walter burnt his first hundred." |
| Stitches | 4. Confident | "Oh, this is wonderful. Thank you. ...I don't think we've met yet. I'm Stitches. It's really nice to meet you." | (his existing lines already work) |

## Co-op: drink served by a chef they don't know

These gaps come from the new lines in Zakk's and Evaroo's bibles, where some right-drink and wrong-drink lines use `[name]`. Their favourite-drink lines are already name-free.

| Regular | Stage | Right drink | Wrong drink |
| --- | --- | --- | --- |
| Zakk | 2. Local | "Thanks, dude. Smooth service." | (his existing line already works) |
| Zakk | 3. Crew | "Cheers, man." He raises his glass to nobody in particular. | (his existing line already works) |
| Evaroo | 2. Tolerating you | "You're new. You got it right. Don't let it go to your head." | "New person, wrong drink. Strong debut." |

## Co-op: seating and Stitches' drink order

**Seating, when the chef seating them is one they don't know**

| Regular | Stage | Lines |
| --- | --- | --- |
| Cheddar | 2. Sidekick | "And the mouse takes a brand-new seat, folks! Hey, new chef. Nice to meet ya." / "New seat, new chef. Big day for everybody." |
| Mabel | 2. Regular | "Thank you, chef. I don't believe we've been introduced. Mabel." / "This will do nicely, chef." |

**Stitches' favourite drink order at stage 3 (Opening up), for a chef he doesn't know**

- "Could I have a hot chocolate, please? ...Sorry, I don't think we've met properly. I'm Stitches."
- "Hot chocolate, please. If it's not too much trouble. The other chef knows how I like it."

## Prompt for Claude Code

Paste this into your console. It points Claude Code at this doc so it can copy the lines in.

```
Add the missing regular lines from the doc "Regulars: Missing Lines (Silent Spots)": https://claude.ai/artifact/9u88BZR36sy3AvKv5xxaxU

1. Mabel: add her "right drink, not her favourite" lines to data/characters/mabel.json for every stage, including -1 and -2.
2. Co-op name-free lines: add the food-served, drink-served and seating lines, and Stitches' stage 3 favourite-drink order, to each character's file. Mark them so they only play when the chef in that moment is one whose name the regular hasn't learned (the same check that currently skips [name] lines).
3. Add a rule to the dialogue system: if every line for a moment would be skipped because of [name], play a name-free line for that moment instead of nothing. Then re-run the silent-spot check across all regulars and list anything still silent.
4. Note in the GDD (Regulars > Dialogue) that every [name]-only moment needs a name-free twin.
```
