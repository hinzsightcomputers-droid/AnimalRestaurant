# Zakk: Character Bible

Oct 29, 2026 · @Alex

## Who Zakk is

Zakk is the most laid-back regular in the restaurant. He never gets angry, never rushes, and calls everyone "dude," including Mabel. His arc is about the first place he ever wanted to stay: your restaurant. His story ends with his wedding to Penny, with the player as his best man.

**Look.** A medium-sized penguin with sunglasses pushed up on his head, a loose flower-print shirt and board shorts. His feet are always a little sandy. Placeholder: a black capsule with a white front panel and a small yellow beak.

**Backstory.** He grew up in a tiny, cold town where everybody fished and nobody surfed. Penguins swim, everyone told him; they don't surf. He taught himself anyway, on a piece of driftwood. Ever since, he has drifted from beach to beach chasing waves, never staying anywhere more than a few weeks. He came to town because the waves are decent here. He planned to stay a week.

**Core truth.** He never gets angry, but not because nothing bothers him. Long ago he decided that holding on to things weighs you down, so he lets everything go, including people. His arc is learning that putting down roots isn't the same as being weighed down.

**Tendencies (things he does, not just says)**

- Leaves a little trail of sand wherever he walks. Cleaning his table includes sweeping up sand.
- Always sits at a window table, facing where the ocean would be.
- Calls everyone "dude" or "man," no matter who they are.
- Checks the surf report on his phone between bites.
- Is the slowest eater in the restaurant and lingers the longest. He's never in a hurry.
- Sometimes leaves a seashell on the table with his tip, as a little gift.
- Says "no worries" to everything, including burnt food.
- Has no disliked dish. He genuinely likes everything.

**Voice rules**

| Stage | How he talks |
| --- | --- |
| Paddling out | Easygoing and friendly. Surf slang. Talks about waves and good vibes. Calls you "dude." |
| Local | Learns your name. Tells you he's been in town longer than he meant to. |
| Crew | Opens up about his hometown, why he never stays anywhere, and the kid from up north. |
| Wave buddy | Talks about the future, which is new for him. Still chill, but he means it. |
| Any negative stage | He never says he's hurt. He stays cheerful but drifts away: shorter visits, farther tables, then gone. |

## Relationship system

Relationship runs from -100 to 100, with four friendly stages and four disliking stages. Every regular uses this scale; Zakk's stages are named below.

| Range | Stage | What unlocks or changes |
| --- | --- | --- |
| 75 to 100 | 4. Wave buddy | "Surprise me" orders. Big moment scene at 85+. |
| 50 to 74 | 3. Crew | Hometown chats. The memory wink line about the kid from up north. |
| 25 to 49 | 2. Local | Learns your name. "What do you recommend?" from 40+. |
| 0 to 24 | 1. Paddling out | Where he starts. |
| -1 to -24 | -1. Coasting | Still friendly, but shorter. |
| -25 to -49 | -2. Drifting | Sits far away, leaves early. |
| -50 to -74 | -3. Out of town | Only orders by phone. |
| -75 to -100 | -4. Gone | Leaves town. Sends a postcard. |

**Four response options every conversation**

Each player choice is tagged with a tone: warm, playful, straight or rude. The rude option is always last in the list so it never gets picked by accident.

| Stage | Warm | Playful | Straight | Rude |
| --- | --- | --- | --- | --- |
| Paddling out | +3 | +3 | +2 | -4 ("All good, man.") |
| Local | +3 | +3 | +2 | -6 |
| Crew | +3 | +3 | +2 | -8 |
| Wave buddy | +2 | +3 | +2 | -10 |
| Any negative stage | +2 | +2 | +2 | -4 |

Zakk is the easiest regular to get along with, because every friendly tone works on him.

**The rude twist.** Zakk never reacts angrily to a rude choice. His reply is always some version of "No worries, dude." The only way to tell he's hurt is what he does: he visits less often (his chance of being picked for the day drops), sits farther from the counter, and leaves sooner. Players who aren't paying attention won't notice until he's gone.

**Rules that keep the dark side intentional**

- One rude choice can never drop him more than one stage in a single visit.
- He can't go below 0 unless you've picked rude at least 3 times in a row with him (tracked as `rude_streak`). Any non-rude choice resets the streak.
- Reaching Out of town or Gone takes many visits of deliberate cruelty. No player gets there by accident.
- Every rude line you choose is saved (`last_rude_line`). Zakk brings it up only once, at Coasting, and says "no worries" right after. His friends will quote it too.

## Dialogue by stage

Your original lines are all kept and placed in the stage where they fit best. \[fav\] is his favorite dish (fish stew).

### Stage 1: Paddling out (0 to 24)

**Arrival**

- First visit ever: "Whoa, nice spot, dude. Smells like a perfect swell in here." / "Hey, new place! Mind if I post up and catch some flavor?" / "Good vibes in here. I can already tell."
- Away 3+ real days: "Yo, been a minute! The tide's been low without you." / "Look who washed back in! I was starting to wonder, dude." / "Hey, you're back. Good to see you again, seriously."
- Away 14+ real days: "Dude, two whole weeks? I almost sent out a search party. Okay, not really. But I thought about it." / "Long time, man. The waves have been mellow, but the stew hasn't been the same."
- Last meal was burnt: "No worries about last time, man. Burnt's just extra crispy, right?" / "It's all good. Everybody wipes out sometimes." / "Hey, I'm not even mad. Can't be, it's not in me."
- Last meal was great: "That was gnarly good last time. I've been thinking about it all week." / "Straight-up barrel-ride flavor. You've got a gift, dude."
- Favorite is on the menu: "Wait, fish stew? You're the best, man." / "Okay, now I'm definitely staying a while."
- Default: "Another good day. Another good wave." / "Cool place, cool people. Can't ask for more." / "Just gonna sit back and soak it in."

**Ordering conversation A**

Zakk: "What's good, dude? Actually, don't tell me. Everything's good. I'm easy."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "I'll make you something really good, then." | "See? Good vibes. I knew it." | +3 |
| Playful | "Easy, huh? I'll bring you a bowl of sand." | "Ha! I've had worse, man. The \[dish\], please." | +3 |
| Straight | "The \[dish\] is great today." | "Sold. No questions." | +2 |
| Rude | "Can you just pick something, please?" | "Oh, totally, no worries. The \[dish\]." Nothing in his voice changes. | -4 |

**Ordering conversation B**

Zakk: "Swell's tiny today. Perfect day to eat instead of surf."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "Lucky for me, then." | "Lucky for both of us, dude." | +3 |
| Playful | "Can penguins even surf?" | "That's what everyone back home said, man. Watch me." | +3 |
| Straight | "What'll it be?" | "The \[dish\]. Hit me." | +2 |
| Rude | "Nobody cares about the waves." | "Ha, fair. No worries." | -4 |

**Ordering conversation C (the sand)**

Zakk: "Oh, man, sorry about the sand. It just kinda follows me."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "Don't worry about it. Sand means you've been somewhere fun." | "Ha. That's a nice way to see it, dude." | +3 |
| Playful | "I'm charging you a sweeping fee." | "Fair. Payment in seashells?" | +3 |
| Straight | "No problem. What can I get you?" | "The \[dish\], man." | +2 |
| Rude | "Can you wipe your feet next time?" | "Oh, totally. My bad, dude. No worries." He picks a table farther in. | -4 |

**Serving**

- Great: "Gnarly. Straight-up gnarly."
- Okay: "Solid, man. Solid."
- Burnt: "Extra crispy. Love that for me."

**Eating chats**

- "Ever surfed? You should. I'll teach you. Free lessons. Payment in stew."
- "I've been to, like, twenty beaches. This town's got a good one. Not the best one. But good."
- He shows you his phone: "Surf report says tomorrow's gonna be epic. Says that every day. Never right. Love it."

**Leaving**

- "Catch you on the next wave, dude."
- He leaves a seashell next to his tip.

### Stage 2: Local (25 to 49)

**Learning your name (plays once at 25)**

> "Hey, I never got your name, dude. ...\[name\]. Rad. That's a good wave name."

**Arrival**

- "You know, this place feels like home break now." / "I tell everyone about this spot. Everyone."
- "\[name\]! My dude. What's cookin'? Literally."
- "Funny thing. I was only gonna stay here a week. That was, like, a month ago."

* Away 3+ real days: "\[name\]! Thought you paddled off somewhere, dude."
* Last meal was burnt: "Last one was a little crispy, man. Still ate it. No worries."
* Last meal was great: "Dude. Last time? Gnarly. I told, like, three people."

**Ordering conversation**

Zakk: "I've been in town for a month now, dude. That's, like, a record for me."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "I hope you stay a lot longer." | "...Huh. Nobody's ever said that to me, man." | +3 |
| Playful | "It's the food. You're trapped now." | "Delicious trap, dude. Best kind." | +3 |
| Straight | "Where were you before this?" | "Everywhere, man. Nowhere long. The \[dish\], please." | +2 |
| Rude | "Hope you leave soon." | "Ha. Yeah, probably. No worries." He looks out the window for a while. | -6 |

**"What do you recommend?" (40+)**

> "What do you recommend, \[name\]? I trust you, man."

- His favorite: "Fish stew?! You get me, dude." (+5)
- Anything else: "Love it. You can't miss with me." (+2). He has no disliked dish.

**Serving**

- "Thanks, \[name\]. You always make it look so easy."

**Eating chat with choices**

Zakk: "You ever feel like you're supposed to be somewhere else? Like there's a better wave down the coast?"

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "Not really. I'm happy right here." | "...That sounds nice, man. Must be nice." | +3 |
| Playful | "Only when I burn things." | "Ha! Then you'd never leave, dude." | +3 |
| Straight | "Sometimes. But I chose to stay." | "Chose to stay. Huh. Never tried that." | +2 |
| Rude | "Then go find it." | "Yeah. Maybe I should." | -6 |

**Leaving**

- "Later, \[name\]. Same wave, same time."

### Stage 3: Crew (50 to 74)

**Arrival**

- "\[name\]! Crew's here. And by crew I mean me."
- "I cancelled a trip down the coast this week. Didn't feel like going. That's weird, right? That's weird for me."

* Away 3+ real days: "There you are, man. I actually missed this place. Weird feeling. Good weird."
* Last meal was burnt: "Bit burnt last time, dude. Telling you 'cause you're crew now. Crew's honest."
* Last meal was great: "Last meal was so good I skipped a surf session for it. That's huge for me."

**The memory wink (plays up to 2 times, during eating)**

> "I knew this one kid, best surfer I ever saw. Came from some cold little town up north, can't remember the name. Rad dude though."

See open questions for who this kid is.

**Ordering conversation**

Zakk: "I don't really stay places, you know? Stay too long, stuff gets heavy."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "Some heavy things are worth carrying." | Long pause. "...Gonna think about that one, dude." | +4 |
| Playful | "Too late. You're a regular. It's in the paperwork." | "Ha! Can't argue with paperwork." | +3 |
| Straight | "You've stayed here pretty long." | "Yeah. I noticed that too." | +2 |
| Rude | "Sounds like an excuse." | "Maybe it is, man. No worries." He orders and doesn't say much else. | -8 |

**Eating chats (personal, one per visit)**

- Hometown: "Grew up in this tiny cold town. Everybody fished. Nobody surfed. Penguins swim, man, we don't surf. That's what they all said."
  - Warm: "And you proved them all wrong." → "...Never thought of it like that. Thanks, dude." (+3)
  - Playful: "Their loss. Bet you surf better than all of them fish." → "Ha! That's not hard, man." (+3)
  - Rude: "Maybe they had a point." → "Ha. Yeah. Maybe." (-8)
- The driftwood: "First board I ever had was a piece of driftwood. Still got it, actually. Carried it to every beach."
- Why he never gets mad: "People think I never get mad 'cause nothing bugs me. Nah. I just figured out holding on to stuff makes you sink."

**Leaving**

- "See you tomorrow, \[name\]. ...Huh. 'Tomorrow.' I never used to know where I'd be tomorrow."

### Stage 4: Wave buddy (75 to 100)

**Arrival**

- "\[name\]! My guy! Best spot on the whole coast, right here."
- "I signed a lease, dude. Like, a whole year. Me. Wild."
- Away 3+ real days: "Dude, where'd you go? I'm supposed to be the one who drifts off!"

* Last meal was burnt: "Burnt last time, dude. Don't care. I'd eat your burnt stuff forever."
* Last meal was great: "Last time was the best meal I've had on any coast. Not even kidding."

**"Surprise me!"**

> "Surprise me, dude. Whatever you make, I'm stoked."

- Favorite: "Fish stew. The best. You're the best." (+3)
- Anything else: "Stoked. Totally stoked." (+2)

**Ordering conversation**

Zakk: "I'm thinking about teaching surf lessons here. Like, staying-here staying. What do you think?"

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "I think this town's lucky to have you." | "...You can't just say stuff like that, dude. I'll cry into my stew." | +2 |
| Playful | "Only if my lessons are free." | "Free forever, man. Payment in stew." | +3 |
| Straight | "Do it. You'd be great." | "Yeah? Yeah. Okay. I'm doing it." | +2 |
| Rude | "Nobody would sign up." | "...Yeah. Probably not. No worries." | -10 |

**Eating chats**

- "Funny thing about staying, dude. It doesn't feel heavy at all. Feels like floating."
- "You're the reason I unpacked. Like, actually unpacked. My stuff's in drawers now, man."

**Leaving**

- "Later, dude. I'll be here tomorrow. And the day after. Get used to it."

## Negative stages

Stitches gets smaller, Cheddar gets sharper, and Mabel gets formal. Zakk just drifts. He never says a hurt word, so the player has to notice what he does instead.

### -1: Coasting (-1 to -24)

- Arrival: "Hey. All good. Just the \[dish\], dude."
- He picks a table one step farther from the counter than usual.
- Fewer eating chats. "Just vibing today, man."

* Arrival quoting you (plays once): "Hey, so... '\[last\_rude\_line\].' Been thinking about it. No worries, though. Seriously." He never brings it up again.

### -2: Drifting (-25 to -49)

- Arrival: "Can't stay long. Waves are calling." (They aren't. He checks his phone and puts it away.)
- He sits at the table farthest from the counter, eats fast, and leaves before you can chat.
- No more seashells.
- Warm choice reaction: "Thanks, man. ...No, really. Thanks." A tiny crack in the chill.

### -3: Out of town (-50 to -74)

He stops coming in. He only calls the phone:

> "Hey, it's Zakk. Just the stew, delivered. I'm gonna catch a wave after. No worries."

Redemption hook: at the end of his call, a kind reply ("Come by sometime. We miss you here.") gives +5. His next call: "...I might, dude. Might."

### -4: Gone (-75 to -100)

He leaves town. A postcard arrives with a picture of a faraway beach:

> "Waves are good out here. Didn't wanna make things weird back there. No worries, dude. Seriously. —Z"

The "no worries" is the saddest part. Other regulars mention it: Cheddar says the beach feels empty, and Mabel says the floors have been suspiciously free of sand.

**Getting him back from Gone**

Gone isn't permanent the first time.

1. **Write back to the postcard.** It has a return address. A letter with no excuses that tells him he has a place here brings a reply a few days later: "Got your letter, dude. Read it on the beach. ...Coming back up. Save me a window seat."
2. **Through a friend.** Ask Evaroo or Cheddar (50+ with them), or his semi-regular friends Cody, Yaniv or Penny (their lines still to write).
   - Evaroo: "Ugh. Fine. I'll call him. He owes me a drum part anyway."
   - Cheddar: "I'll lure him back. I'll say the waves are huge here. They're not. He'll be furious. Then he'll stay."

**The return scene**

He comes in at closing with sand on his feet and his sunglasses down, which he never does.

> **Zakk:** "Hey, dude. ...So. I came back. I never come back to places."

| You say | He says |
| --- | --- |
| "I'm sorry. I treated you badly, and you didn't deserve it." | He pushes his sunglasses up. "Thanks, man. That means a lot. Like, actually." |
| "You can tell me when I hurt you, you know." | "...Yeah. I'm not great at that. Gonna try." |
| "Your window seat's still open." | "...Yeah? Cool. Cool." He sits down. |

He returns at 0, at Paddling out. A second fall to Gone is permanent: the next postcard has no return address.

## The driftwood board scene

The drifter decides to stay. Zakk brings you the driftwood he learned to surf on, the one thing he has carried to every beach, and asks you to hang it on the restaurant wall.

**Trigger:** relationship 85+, all hometown chats heard, at least 3 visits at Wave buddy, `big_moment_done` is false.

**Staging:** Closing, at sunset. Golden light pours through the windows. Soft wave sounds under a mellow version of the main theme. No phone calls that evening.

### Script

Zakk comes in carrying something long wrapped in an old beach towel.

> **Zakk:** "Hey, dude. Got a sec? Got a thing."

He unwraps it: a battered, sun-bleached piece of driftwood, carved roughly into the shape of a surfboard.

> **Zakk:** "First board I ever had. Found it on the beach back home when I was a kid. Everyone laughed. Penguin on a stick, they said."
>
> **Zakk:** "I've carried this thing to every beach I ever went to. Twenty-something beaches. Never hung it up anywhere. 'Cause I never knew if I was staying."

**Choice 1**

- "It's amazing, Zakk." → "It's a stick, dude. ...But thanks. It's a good stick."
- "You surfed on THAT?" → "Badly! For like a year! Then I got good."
- "Why show me now?" → "'Cause I figured something out, man."

> **Zakk:** "Every place I've ever been, I kept one foot out the door. Made it easy to leave. Nothing heavy, you know?"
>
> **Zakk:** "But this place... You remember stuff about me. You notice when I'm quiet. You made me feel like it's okay to stick around."
>
> **Zakk:** "So I want this up on your wall. Then wherever I go, a part of me stays here. And honestly, dude? I'm not going anywhere."

**Choice 2**

- "It'll be the first thing everyone sees when they walk in." → "Perfect, man. Perfect."
- "Welcome home, Zakk." → He takes his sunglasses off. For once, he doesn't have a surf word for it. "...Yeah. Home."
- "Does this mean I get free surf lessons now?" → "For life, dude. Payment in stew."

The two of you hang the board on the wall together while the sun goes down.

### After the scene

- The driftwood board becomes a permanent decoration on the restaurant wall.
- Zakk sometimes taps it for luck when he walks in.
- Other regulars notice. Cheddar: "Is that a STICK? On the WALL?" Mabel: "It's a very nice stick, dear."

## Penny and the wedding

Penny the Penguin, a shy bookworm and semi-regular, is Zakk's love interest. She's scared of water and won't swim, but she loves being near it. Partway through his storyline the player helps set them up, Zakk helps her get over her fear of water, and his story ends with their wedding, with the player as his best man. The driftwood board scene is where he decides to stay, and the wedding comes after it.

| Beat | What happens | Suggested timing |
| --- | --- | --- |
| Meeting | Zakk and Penny meet at the restaurant. | Local |
| Setup | The player helps set them up. | Crew |
| Dating | They start seeing each other, and Zakk helps her get over her fear of water. | Crew to Wave buddy |
| Engagement | Zakk and Penny get engaged. | After the driftwood board scene |
| Wedding | The end of Zakk's story, with the player as his best man. | After the engagement |

Zakk and Penny both need lines for each beat (still to write). Penny's are in her semi-regular file.

**Wedding ideas:** bake the wedding cake as a close-up; reward a framed wedding photo; Miles as the photographer.

## Friends, gossip and referrals

### How gossip works (all characters)

- Each regular has a `friends` list.
- When you cross a stage boundary with someone, or pick a rude line with them, a gossip event is queued for each of their friends (`pending_gossip`).
- The friend brings it up once, on their next visit, during ordering or eating. Rude gossip quotes the exact line you said.
- Your response to the friend matters to both characters. Apologizing gives +3 to the hurt character as well, because the friend passes it on.

### Zakk's friends

| Friend | When it starts | What it's like |
| --- | --- | --- |
| Evaroo | From the start | Zakk plays drums in Evaroo's band and calls him "Roo." Evaroo acts annoyed by him constantly. Zakk thinks he's the funniest guy alive. |
| Cheddar | Both at 50+ | Two fun guys. Cheddar tries to learn surfing and is terrible at it. |
| Mabel | Both at 50+ | He calls her "dude." She pretends to hate it. She doesn't. |
| Cody | Semi-regular | Friends, and part of a gaming trio with Yaniv. |
| Yaniv | Semi-regular | Friends, and part of a gaming trio with Cody. |
| Penny | Semi-regular | His love interest. See Penny and the wedding. |

Semi-regular friends mention Zakk in their lines, and gossip about him reaches them. They sometimes come in with him: it counts as his visit, and they tag along.

**Evaroo about Zakk**

- Kind: "Zakk won't shut up about you. It's annoying. ...He says you're the reason he stayed. Don't make it weird."
- Rude: "Zakk told me you said "\[last\_rude\_line\]". He said 'no worries' like six times. That's how I know it got to him. You didn't mean it, did you?"

| You say | Evaroo says | Effect |
| --- | --- | --- |
| "I didn't. I'll make it right." | "Good. He'd never ask you to. That's why you have to." | Evaroo +2, Zakk +3 |
| "He said no worries." | "He always says that. That's the problem." | Evaroo 0 |
| "Yeah, I meant it." | "...Wow. Okay." | Evaroo -10 |

**Zakk about his friends**

- You were kind to Evaroo: "Roo smiled at band practice yesterday, dude. Like, a real one. Said it was 'nothing.' I think it was you."
- You were rude to Evaroo: "Hey, man. Roo's been extra quiet. He doesn't do quiet. ...Did something happen?"
- You were kind to Cheddar: "Cheddar says you laughed at all his jokes yesterday. Even the shark one. Respect, dude."
- You were rude to Stitches: "The bear with the patches seemed bummed, man. Not my business. But... be good to him, yeah?" (Zakk doesn't need to be friends with someone to stick up for them.)

**Referral:** later.

## Data fields and open questions

These fields are the same for every regular, so Claude Code can build the system once for all characters. Zakk adds a few of his own.

| Field | Type | What it's for |
| --- | --- | --- |
| relationship | number, -100 to 100 | Current relationship |
| rude\_streak | number | Rude choices in a row; must reach 3 before going below 0 |
| last\_rude\_line | text | Quoted back once by him, and by his friends |
| tone\_reactions | table per stage | The warm/playful/straight/rude values above |
| friends | list of ids | Who hears about how you treat this character |
| pending\_gossip | list | Events a friend will bring up next visit |
| referral\_only | true/false | Never visits unless someone recommends them |
| referred\_by | id | Who introduced them |
| big\_moment\_done | true/false | Driftwood board scene has played |
| seen\_lines | list of ids | So the same line doesn't repeat too soon |
| hometown\_chats\_heard | list of ids | Which Crew-stage hometown chats have played (needed for his scene) |
| memory\_wink\_plays | number | How many times the "kid from up north" line has played (max 2) |
| visit\_weight | number | Lowered by rude choices so he quietly visits less often |
| penny\_beat | text | How far his story with Penny has got: meeting, setup, dating, engagement or wedding |

**Open questions for you**

- [ ] **The memory wink.** Who is "the kid from the cold little town up north"? It could be Zakk himself (penguins aren't from up north, so he might be hiding it), the player character (which would mean they knew each other as kids), or a future referral character.
- [ ] Zakk's and Penny's lines for each wedding story beat.
- [ ] Should the timing in Penny and the wedding change?
- [ ] Favorite drink: lemonade?
- [ ] Is he Evaroo's drummer?
- [ ] Are the seashell tips just a cute detail, or collectible?
- [ ] Any lines that don't sound like him? Edit them right in this doc.
