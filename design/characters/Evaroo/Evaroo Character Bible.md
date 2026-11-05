# Evaroo: Character Bible

Oct 29, 2026 · @Alex

## Who Evaroo is

Evaroo is the restaurant's resident critic: deadpan, sarcastic, and impossible to impress, especially about the music. Underneath, he's one of the most caring characters in the game, and he'd rather die than admit it. His arc is about letting you hear something he made that's honest.

**Look.** A tall kangaroo in an oversized band T-shirt, with headphones around his neck and half-lidded, unimpressed eyes. His pouch holds guitar picks, earbuds and a battered notebook full of lyrics. Placeholder: a tall, tan capsule with a small box on the front for the pouch.

**Backstory.** He's the singer and guitarist of a small band that plays the same tiny venue every Friday to about nine people. Zakk plays drums. He writes songs constantly, but the band only ever plays covers. His own songs are too honest, and that terrifies him. Sarcasm is the armor he wears so nobody gets close enough to hurt him. He usually comes in alone, though his friend Rush sometimes tags along.

**Core truth.** He notices everything: when you're tired, when the bear in the corner is sitting alone, when the music is bad. He quietly does something about it, then denies it. His sarcasm is never cruel to people who are already down.

**Tendencies (things he does, not just says)**

- Judges whatever music is playing in the restaurant, out loud.
- Taps rhythms on the table with his chopsticks while he waits.
- Writes in the notebook from his pouch, and snaps it shut when you walk over.
- Rates everything out of ten, deadpan. "Soup: six. Lighting: four. You: pending."
- Wears his headphones at the table early on. As he warms up to you, he takes them off sooner, and in the end he stops wearing them here at all.
- Hides his tip under the plate. It's always bigger than he'd ever admit.
- Makes a face at anything bitter: coffee, black tea, matcha.

**Voice rules**

| Stage | How he talks |
| --- | --- |
| Critic | Deadpan, dry, judges everything. Short sentences. Sarcasm on every line. |
| Tolerating you | Same sarcasm, softer edges. Uses your name by accident and is annoyed about it. |
| Backstage | Talks about music and the band. Genuine moments slip out, and he undercuts them right away. |
| Bandmate | Still sarcastic, but openly fond of you in his own way. Says real things, briefly. |
| Any negative stage | He stops being sarcastic. He's polite, flat and distant. Polite Evaroo is the danger sign. |

## Relationship system

Relationship runs from -100 to 100, with four friendly stages and four disliking stages. Every regular uses this scale; Evaroo's stages are named below.

| Range | Stage | What unlocks or changes |
| --- | --- | --- |
| 75 to 100 | 4. Bandmate | "Surprise me" orders. Headphones off for good. Big moment scene at 85+. |
| 50 to 74 | 3. Backstage | Talks about his songs and the band. The notebook chats. |
| 25 to 49 | 2. Tolerating you | Uses your name (by accident). "What do you recommend?" from 40+. |
| 0 to 24 | 1. Critic | Where he starts. |
| -1 to -24 | -1. Flat | Less sarcasm, which is not a good thing. |
| -25 to -49 | -2. Polite | Perfectly polite. Terrifying. |
| -50 to -74 | -3. Headphones on | Only orders by phone. |
| -75 to -100 | -4. Gone | Stops ordering. Writes a song about it. |

**Four response options every conversation**

Each player choice is tagged with a tone: warm, playful, straight or rude. The rude option is always last in the list so it never gets picked by accident.

| Stage | Warm | Playful | Straight | Rude |
| --- | --- | --- | --- | --- |
| Critic | 0 ("Ew. Feelings.") | +4 | +3 | -5 ("Wow. Cute.") |
| Tolerating you | +1 | +4 | +3 | -8 |
| Backstage | +3 | +3 | +3 | -10 |
| Bandmate | +3 | +3 | +2 | -12 |
| Any negative stage | +1 | 0 (he doesn't laugh) | +3 | -6 |

Playful with Evaroo means banter: a dry comeback, not a goofy joke. Cheddar wants you to laugh at his jokes. Evaroo wants you to keep up with his. Warmth makes him squirm early on, but by Backstage he quietly needs it.

Rude hurts more the closer you are, because he finally let his guard down. Climbing back from negative is slow on purpose: he forgives, but he puts the headphones back on first.

**Rules that keep the dark side intentional**

- One rude choice can never drop him more than one stage in a single visit.
- He can't go below 0 unless you've picked rude at least 3 times in a row with him (tracked as `rude_streak`). Any non-rude choice resets the streak.
- Reaching Headphones on or Gone takes many visits of deliberate cruelty. No player gets there by accident.
- Every rude line you choose is saved (`last_rude_line`) so he, or later his friends, can quote it back to you.

**The music system.** Evaroo is the reason the restaurant needs a radio or jukebox. The player picks what plays, and each song is tagged good or bad for him. His music lines (in the dialogue section) react to it, and playing a song he likes gives +2 once per visit. Later, his own song can be added to the jukebox (see his big moment).

## Dialogue by stage

Your original lines are all kept and placed in the stage where they fit best.

### Music reactions (any friendly stage)

These play at arrival or while eating, depending on what's on the radio.

- Bad song: "Whoever picked this song owes me an apology." / "Is this the best the speakers can do? Because it isn't."
- Good song: "Okay. This one's actually good. Don't tell anyone I said that." / "Finally, someone with taste. Leave it on."

### Stage 1: Critic (0 to 24)

**Arrival**

- First visit ever: "Nice place. The music's rough, but the place is fine." / "I was told this was the good restaurant. We'll see." / "Table for one. Try to contain your excitement."
- Away 3+ real days: "Oh, you're alive. I assumed you'd quit and I was weirdly fine with it." / "Back again. I'd say I missed this place, but that would be a lie. Mostly."
- Away 14+ real days: "Two weeks. I almost forgot what your cooking tasted like. Almost." / "Wow, you're back. Did the band break up, or did you?"
- Last meal was bad: "Wow. Did you cook that last time or just find it?" / "I've eaten worse. Not recently, though." / "Let's try that again, and this time, with feeling."
- Last meal was great: "Not bad last time. Don't let it go to your head." / "Fine. That was good. Happy now?"
- Favorite is on the menu: "Sushi's on the menu. Okay, you have my attention." / "Sushi. Alright, maybe you do know what you're doing."
- Default: "Food's fine. The music, however."

**Ordering conversation A**

Evaroo: "What's good here? And don't say 'everything.' Nobody's everything is good."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "I'll make you something really special." | "'Special.' Bold claim. The \[dish\]." | 0 |
| Playful | "Honestly? The napkins. Five stars." | "...Okay, that was almost funny. The \[dish\]." | +4 |
| Straight | "The \[dish\]. It's what I make best." | "See, that's an answer. Fine." | +3 |
| Rude | "Then go eat somewhere else." | "Wow. Cute. The \[dish\]." | -5 |

**Ordering conversation B (the music)**

Evaroo: "Who picks the music in here? Because I have notes."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "You can pick next time, if you want." | "...Don't tempt me." | +1 |
| Playful | "It's my grandma's playlist. Be nice." | "Your grandma has terrible taste. Tell her I said hi." | +4 |
| Straight | "Me. What should I play instead?" | "Finally, someone asks. Anything with a real drummer." | +3 |
| Rude | "Nobody asked for your notes." | "Nobody ever does." | -5 |

**Ordering conversation C (the headphones)**

Evaroo: "Don't mind the headphones. I'm not ignoring you. I'm ignoring everyone, generally."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "That's okay. Order whenever you're ready." | "...Huh. Okay. Thanks." | 0 |
| Playful | "Good. I was going to ignore you first." | "...Okay, that's fair. Respect." | +4 |
| Straight | "What are you listening to?" | "Stuff you haven't heard of. ...It's good, though." | +3 |
| Rude | "Then take them off. It's rude." | "Wow. Cute." He doesn't take them off. | -5 |

**Serving**

- Great: "Fine. That looks good. Happy now?"
- Okay: "It's food. It's on a plate. Six out of ten."
- Bad: "Charcoal. Interesting artistic choice."
- Served something bitter: "This is bitter. Why is this bitter? Who did this to me?" / "I'd say thank you, but my taste buds are filing a complaint."

**Eating chats**

- He's wearing his headphones. When you walk up, he takes out one earbud. "Yes?"
- "Soup: six. Lighting: four. You: pending."
- "My band plays Fridays. Nine people come. Ten if Zakk's mom is in town."

**Leaving**

- "Bye. I'll be back. Probably. Don't wait up."
- His tip is hidden under the plate, and it's bigger than it needs to be.

### Stage 2: Tolerating you (25 to 49)

**Learning your name (plays once at 25)**

> "Thanks, \[name\]. ...Ugh. I said your name. Forget that happened."

**Arrival**

- "It's me again. Act surprised."
- "Zakk says hi. I didn't want to pass that on, but he wouldn't stop."

* Away 3+ real days: "You were gone. I noticed. Don't make it a thing."
* Last meal was burnt: "Last time was burnt. Four out of ten. Down from six."
* Last meal was great: "Last meal was an eight. I'm telling you so you don't get lazy."

**Ordering conversation**

Evaroo: "Band practice was a disaster. Zakk dropped a drumstick into his own snack. Twice."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "Sounds like you needed a good meal, then." | "...Yeah. Maybe. The \[dish\]." | +1 |
| Playful | "Twice? That's commitment." | A tiny snort, instantly denied. "I didn't laugh. The \[dish\]." | +4 |
| Straight | "What happened after?" | "He ate the snack. Drumstick and all. Basically." | +3 |
| Rude | "Your band sounds terrible." | "Nine people disagree. Barely." | -8 |

**"What do you recommend?" (40+)**

> "Sure. Whatever you recommend. I'll judge it either way."

- His favorite: "Sushi. ...Fine. You've been paying attention. Don't let it go to your head." (+5)
- Anything else: "Okay. Seven. Maybe eight. Don't push it." (+1)

**Eating chat with choices**

Evaroo: "I rate everything. Your turn. Rate me. Out of ten. Go."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "Ten. Easy." | "...Ew. Okay. That's. Okay." He puts his headphones back on fast. | +1 |
| Playful | "Six. Lighting's bad." | "Ha. Fair. Respect." | +4 |
| Straight | "Eight. You'd be ten if you smiled more." | "Bold. Wrong. But bold." | +3 |
| Rude | "Two." | "Wow. Okay." | -8 |

**Leaving**

- "Bye, \[name\]. ...I'm saying it on purpose now. Don't read into it."

### Stage 3: Backstage (50 to 74)

**Arrival**

- "...You're doing okay here. Don't make it weird."
- "I'm not saying I like this place. I'm just here a lot. Draw your own conclusions."
- He doesn't put his headphones on at all today.

* Away 3+ real days: "...You were gone a few days. The place felt off. Not saying I missed it. Just noting it."
* Last meal was burnt: "Burnt last time. I'm telling you because I know you can do better. That's a compliment. Kind of."
* Last meal was great: "Last meal: nine. I wrote it in my notebook. Don't ask."

**Ordering conversation**

Evaroo: "My band's playing Friday. I'm not inviting you. But if you happened to show up, nobody would stop you."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "I'd love to hear you play." | "...You'd hate it. It's all covers. Whatever." | +3 |
| Playful | "Will there be a drumstick in a snack?" | "Probably. That's half the show." | +3 |
| Straight | "Why only covers?" | "...Order first. I'll tell you later. Maybe." | +3 |
| Rude | "Nobody wants to see that." | "Yeah. Nine people, remember?" | -10 |

**Eating chats (personal, one per visit)**

- The notebook: "I write songs. Like, a lot. We've never played one. Only covers."
  - Warm: "I bet they're really good." → "...You don't know that." A pause. "Thanks, though." (+3)
  - Playful: "Let me guess. They're all about how bad the music is in here." → "Only, like, three of them." (+3)
  - Straight: "Why not play them?" → "Covers are safe. They're somebody else's feelings. Mine are... a lot." (+3)
  - Rude: "Probably for the best." → He closes the notebook and doesn't open it again. (-10)
- The bear in the corner: "People are jerks to that bear with the patches. I sat next to him at the park yesterday. Didn't say anything. Just sat there. ...Don't tell anyone."
- "You ever make something and get scared to show anyone? ...Forget I asked."

**Leaving**

- "See you, \[name\]. ...Thanks. For the food. And stuff."

### Stage 4: Bandmate (75 to 100)

**Arrival**

- "\[name\]. Good. You're here. The music's still bad, but you're here."
- "I brought a playlist for your radio. You're welcome. It's a gift. Don't say anything."
- Away 3+ real days: "You disappeared. I had to eat Zakk's cooking. Never again."

* Last meal was burnt: "Burnt last time. Still a seven. You get points for being you."
* Last meal was great: "Last time was a ten. First ten I've ever given. Frame it."

**"Surprise me!"**

> "I'll have the usual. If I had a usual. Surprise me."

- Favorite: "Sushi. Okay. You win. You always win." (+3)
- Anything else: "Hm. Eight. ...Nine. Don't tell anyone." (+2)

**Ordering conversation**

Evaroo: "I've been working on something. A song. One of mine. Don't ask about it."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "I won't ask. But I'm really proud of you." | "...You can't just say that. Ugh. Thank you." | +3 |
| Playful | "Is it about my soup?" | "Partly. Don't let it go to your head." | +3 |
| Straight | "I'll be here whenever you want to share it." | "I know. That's kind of the problem." | +2 |
| Rude | "Probably won't be any good." | Long silence. "...Wow." | -12 |

**Eating chats**

- "Hey. ...You're a ten. Don't make me say it twice."
- "I used to wear headphones everywhere so nobody would talk to me. Weird that I stopped here, huh?"

**Leaving**

- "See you tomorrow, \[name\]. That's not a promise. It's a fact."

## Negative stages

Evaroo's sarcasm is how he shows he's comfortable. When he's hurt, it disappears. The less sarcastic he is, the worse things are.

### -1: Flat (-1 to -24)

- Arrival: "Hi. Table for one." No joke after it.
- Ordering: "Sushi. Thanks."
- His headphones stay on the whole visit.
- No music comments, good or bad. He's stopped caring what's playing.

* Arrival quoting you: "You said "\[last\_rude\_line\]". Noted." No joke after it.

### -2: Polite (-25 to -49)

- Arrival: "Good afternoon. Thank you for having me." Perfectly polite. Deeply unsettling.
- Serving: "Thank you very much. It looks lovely." He has never said "lovely" in his life.
- The tip is the exact amount, not hidden under the plate.
- Straight choice reaction: "...Okay. Thanks for being honest, at least."

### -3: Headphones on (-50 to -74)

He stops coming in and only calls the phone, flat and short:

> "Sushi. Delivered. Thanks."

Redemption hook: at the end of his call, an honest reply ("I was out of line. I'm sorry.") gives +5. His next call: "...Heard you. Still thinking."

### -4: Gone (-75 to -100)

He stops ordering entirely. A few days later, Zakk mentions that the band finally played one of Evaroo's own songs for the first time. It was about a restaurant that used to feel like home. He doesn't say which restaurant. He doesn't have to.

**Getting him back from Gone**

Gone isn't permanent the first time.

1. **An honest letter.** For Evaroo, the letter must be straight: no excuses and no flattery. If it works, his reply comes as a single line: "Read your letter. It was honest. I hate that it worked. Coming by."
2. **Through a friend.** Ask Zakk (50+).
   - Zakk: "I'll talk to Roo, dude. He acts tough, but he's been sad-writing for like a week. Not a great sign."

**The return scene**

He comes in at closing with his headphones on, stands by the door and takes them off.

> **Evaroo:** "So. I wrote a song about this place. It's not a nice one."

| You say | He says |
| --- | --- |
| "I deserved that song. I'm sorry." | "...Yeah. You did. Thanks for saying it." |
| "I'd like the chance to earn a better one." | A long pause. "That's a good line. Annoyingly good." |
| "Can I play something you like on the radio?" | "...Fine. One song. Then we'll see." |

> **Evaroo:** "Table for one. ...Try to contain your excitement." His first joke in weeks.

He returns at 0, at Critic. A second fall to Gone is permanent.

## The Table for One scene

Evaroo plays one of his own songs for the first time ever, for an audience of one: you. The song is about coming to your restaurant alone and slowly not feeling alone anymore.

**Trigger:** relationship 85+, all notebook chats heard, at least 3 visits at Bandmate, `big_moment_done` is false.

**Staging:** Closing. The radio is off. Just one warm light over the stage corner (or his usual table, if there's no stage yet). No phone calls that evening.

### Script

Evaroo comes in late, with no headphones. He pulls a small acoustic guitar out of his pouch. (It shouldn't fit. Nobody comments on it.)

> **Evaroo:** "Okay. Don't talk. If you talk, I'll stop. Sit down."

The player sits at a table.

> **Evaroo:** "I've written about two hundred songs. I've played zero of them for anyone. This one's... about here. It's called 'Table for One.' ...Don't laugh."

He plays. The song is a short, gentle guitar piece with a few lines of lyrics on screen. *(Lyrics to write: about walking in alone, sitting at the same table, and someone who remembered his order before he said it.)*

When it ends, he stares at the guitar instead of at you.

**Choice 1**

- "That was beautiful." → "...Shut up." A pause. "No, don't shut up. Say it again."
- "Ten out of ten." → "You can't use my system against me. ...Okay, you can."
- Clap slowly, then faster. → He hides his face in his hands. "Stop. Stop! Okay, keep going."

> **Evaroo:** "I always said table for one like it was a joke. It wasn't really a joke. I just didn't want anyone to sit with me and then leave."
>
> **Evaroo:** "And then you kept remembering things. My order. That I hate bitter stuff. Which songs I like. You never once made me feel like too much."
>
> **Evaroo:** "So I wrote it down. And you're the first person who heard it. That's it. That's the whole thing. I'm leaving now."

He doesn't leave.

**Choice 2**

- "Play it at your show on Friday." → "...Maybe I will. If I do, you're coming. That's not an invitation, it's a fact."
- "You're never a table for one here." → He doesn't have a comeback. For the first time, he just smiles.
- "Can I put it on the restaurant radio?" → "If you play it every day, I'll be annoyed. ...Play it every day."

### After the scene

- "Table for One" is added to the restaurant radio as a song you can play. Evaroo pretends to be embarrassed every time it comes on.
- His band poster goes up on the restaurant wall.
- Zakk mentions it: "Roo played his own song at the show, dude! First time ever! Ten people came. TEN!"

## Friends, gossip and referrals

### How gossip works (all characters)

- Each regular has a `friends` list.
- When you cross a stage boundary with someone, or pick a rude line with them, a gossip event is queued for each of their friends (`pending_gossip`).
- The friend brings it up once, on their next visit, during ordering or eating. Rude gossip quotes the exact line you said.
- Your response to the friend matters to both characters. Apologizing gives +3 to the hurt character as well, because the friend passes it on.

### Evaroo's friends

| Friend | When it starts | What it's like |
| --- | --- | --- |
| Zakk | From the start | His drummer. Evaroo acts annoyed by him constantly, but he'd fight anyone who was mean to him. Zakk calls him "Roo." |
| Stitches | Both at 50+ | He sat next to Stitches at the park without saying a word. That's how he befriends people. |
| Rush | Semi-regular | Friends. They mention each other, gossip about Evaroo reaches Rush, and Rush sometimes tags along (it counts as Evaroo's visit). If Evaroo goes Gone, the player can ask Rush to help win him back (lines still to write). |
| Cheddar | Both at 50+ | He's the one person who never laughs at Cheddar's jokes, until the day he does. Cheddar considers it his life's greatest achievement. |

**Zakk about Evaroo**

- Kind: "Roo smiled at band practice yesterday, dude. Like, a real one. Said it was 'nothing.' I think it was you."
- Rude: "Hey, man. Roo told me you said "\[last\_rude\_line\]". He said he didn't care. Then he wrote, like, four sad songs. You didn't mean it, did you?"

| You say | Zakk says | Effect |
| --- | --- | --- |
| "No. I'll apologize to him." | "Good. Bring sushi. He pretends sushi doesn't fix things. It does." | Zakk +2, Evaroo +3 |
| "He's sarcastic. He can take it." | "That's his armor, dude. Armor still dents." | Zakk 0 |
| "Yeah, I meant it." | He takes off his sunglasses. "...Not cool, man. Not cool." | Zakk -10 |

**Evaroo about his friends**

- You were kind to Zakk: "Zakk won't shut up about you. It's annoying. ...He says you're the reason he stayed. Don't make it weird."
- You were rude to Zakk: "Zakk told me what you said. He said 'no worries' like six times. That's how I know it got to him. Not cool."
- You were rude to Stitches: "Did you say something to the bear? Because he's been sitting even smaller. ...I'm not asking. I'm telling you to fix it." His secretly caring side, out loud for once.
- You were kind to Cheddar: "Cheddar told me you laughed at his shark joke. That joke is terrible. You're a better person than me."

**Referral:** later.

## Data fields and open questions

These fields are the same for every regular, so Claude Code can build the system once for all characters. Evaroo adds a few of his own.

| Field | Type | What it's for |
| --- | --- | --- |
| relationship | number, -100 to 100 | Current relationship |
| rude\_streak | number | Rude choices in a row; must reach 3 before going below 0 |
| last\_rude\_line | text | Quoted back by him and his friends |
| tone\_reactions | table per stage | The warm/playful/straight/rude values above |
| friends | list of ids | Who hears about how you treat this character |
| pending\_gossip | list | Events a friend will bring up next visit |
| referral\_only | true/false | Never visits unless someone recommends them |
| referred\_by | id | Who introduced them |
| big\_moment\_done | true/false | Table for One scene has played |
| seen\_lines | list of ids | So the same line doesn't repeat too soon |
| notebook\_chats\_heard | list of ids | Which Backstage notebook chats have played (needed for his scene) |
| music\_bonus\_today | true/false | Whether he's already had his +2 for a good song this visit |

**Open questions for you**

- [ ] Sushi isn't on the menu yet. Add it, maybe as an unlock?
- [ ] His dislike is "bitter drinks." Does that mean coffee, black tea and matcha latte? Mabel's favorite is black tea, which could make a fun clash.
- [ ] Favorite drink: banana milk? A cute drink he'd deny loving would suit him.
- [ ] The music system: a radio or jukebox needs building. Good fit for a restaurant addition.
- [ ] What's his band called?
- [ ] Do you want to write the lyrics for "Table for One" yourself?
- [ ] Any lines that don't sound like him? Edit them right in this doc.
