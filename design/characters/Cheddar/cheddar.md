# Cheddar: Character Bible

Oct 27, 2026 · @Alex

## Who Cheddar is

Cheddar is the funniest regular in the restaurant, and his jokes are how he makes sure nobody forgets he's there. His arc is about the player becoming the first person who laughs at his jokes *and* notices when he isn't joking.

**Look.** A small, bright orange mouse with big ears, a long tail that never stops moving, and a tiny backwards cap. Placeholder: a small orange capsule, the smallest character in the restaurant.

**Backstory.** He's the youngest of fourteen siblings. In a house that loud, the only way to get noticed was to be the funniest one at the table. Everyone has always given him cheese because of his name and his color, and nobody ever asked what he actually likes. He hates cheese. He's been too busy making people laugh to say so.

**Core truth.** He's playful all the way through, but under the bits is someone who wants to be *seen*, not just laughed at. He never punches down. His pranks are harmless, and he'd never joke about someone's insecurity.

**Tendencies (things he does, not just says)**

- Never sits in the same seat twice. "Gotta keep you guessing."
- Tail flicks faster the more excited he is. When he's sad, it stops moving.
- Pulls small, harmless pranks: a sticky note under a table, a fake spider in the napkin holder, swapping the salt and pepper labels. (See "Pranks" in the dialogue section.)
- Narrates his own life like a sports commentator. "And the mouse sits down! The crowd goes wild!"
- Gets bored if he waits too long and starts drumming on the table.
- Gives everyone nicknames. Once he likes you, you get one too.
- Is the first regular who can say "Surprise me," because he loves not knowing what's coming.

**Voice rules**

| Stage | How he talks |
| --- | --- |
| Showman | All bits, puns and dramatic voices. Testing whether you'll play along. Deflects anything sincere with a joke. |
| Sidekick | Brings you into his bits. Gives you a nickname. Starts using your name sometimes. |
| Real talk | Sincere moments slip out between jokes, then he panics and makes a joke to cover it. |
| Best friend | Still hilarious, but he can say something real without hiding behind a punchline. |
| Any negative stage | His jokes get sharper. Playful turns into sarcastic, then into silence. A quiet Cheddar is the worst sign. |

## Relationship and tones

Cheddar uses the same -100 to 100 scale and the same rude-option rules as Stitches (3 rude choices in a row before going below 0, one stage drop per visit at most). What's different is how each tone lands on him.

| Range | Stage | What unlocks or changes |
| --- | --- | --- |
| 75 to 100 | 4. Best friend | Calls you "partner." Big moment scene at 85+. Can refer a friend. |
| 50 to 74 | 3. Real talk | Sincere eating chats. Can prank him back and he loves it. |
| 25 to 49 | 2. Sidekick | Learns your name, gives you a nickname. "Surprise me" from 40+ (earlier than anyone else). |
| 0 to 24 | 1. Showman | Bits, pranks and testing you. Where he starts. |
| -1 to -24 | -1. Snarky | Jokes turn into digs. |
| -25 to -49 | -2. Cold | Sarcasm only. No pranks. |
| -50 to -74 | -3. Withdrawn | Only orders delivery, with sarcastic notes. |
| -75 to -100 | -4. Gone | Stops ordering. Leaves a last joke that isn't funny. |

**Tone reactions**

| Stage | Warm | Playful | Straight | Rude |
| --- | --- | --- | --- | --- |
| Showman | +1 (he deflects it with a joke) | +4 | -2 ("Booooring.") | -4 (he laughs it off as a roast) |
| Sidekick | +2 | +4 | -1 | -8 |
| Real talk | +4 (he finally lets it land) | +3 | 0 | -12 |
| Best friend | +3 | +3 | +1 | -12 |
| Any negative stage | +1 | +3 (a real laugh is the way back) | 0 | -6 |

**The rude twist.** Early on, rude choices only cost -4, because Cheddar treats them like a roast and laughs: "Ooh, ROASTED! Okay, chef!" It looks like it didn't hurt him. It did. Once he reaches Real talk, he brings up the saved `last_rude_line`: "Remember when you said "\[last\_rude\_line\]"? I laughed. ...It wasn't that funny, actually." Players learn that the funny guy was keeping score of the things that stung.

## Dialogue by stage

&#91;dish\] is filled in from the menu; \[cheese dish\] is whichever menu dish is cheesiest; \[name\] needs `knows_player_name`; \[nickname\] is the nickname you pick in stage 2.

### Pranks (any friendly stage)

About once every three visits, Cheddar pulls a small prank before or after he eats. You get a reaction choice.

| Prank | What happens |
| --- | --- |
| Sticky note | A note under table three: "You looked. —C" |
| Fake spider | A paper spider in the napkin holder. He watches from his seat, trying not to laugh. |
| Label swap | The salt and pepper labels are switched. "I have no idea who did that. Must've been a ghost. A mouse-shaped ghost." |
| Tiny sign | A sign on the cooking station: "World's Okayest Chef." At Best friend it says "World's Best Chef (don't tell anyone I said that)." |

Reactions: laugh (+3), pretend to be scared (+2), ignore it (-1, "Tough crowd"), get annoyed (rude, normal rude cost). From Real talk on, a "Prank him back" option appears, which he loves (+5).

### Stage 1: Showman (0 to 24)

**Arrival**

- First visit ever: "Ladies and gentlemen, he has ARRIVED. ...It's me. I'm the 'he.' Hi. Nice place. Do you do takeout? Kidding, I'm staying."
- "And the mouse enters the building! The crowd goes wild! ...The crowd is you. Go wild."
- "New seat today. Gotta keep you guessing."
- Away 3+ real days: "Oh, NOW you're open? I came by and it was just me and a closed sign. We had a nice chat. It's a great listener."
- Last meal was burnt: "Last time was extra crispy. Like, fossil crispy. I'm giving you a second chance because I'm generous."
- Last meal was great: "Okay, I've been thinking about my last meal here. Like, a weird amount. Don't make it weird."

**Ordering conversation A**

Cheddar: "Okay, okay, don't tell me the menu. I'm gonna guess. ...Is it soup? It's soup, isn't it."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "You can order whatever you like. Take your time." | "Aw, look at you being all nice. Suspicious. I'll have the \[dish\]." | +1 |
| Playful | "It's actually all soup. Every dish. Soup restaurant." | "I KNEW it. Give me the soupiest soup you've got." | +4 |
| Straight | "Here's the menu." | "Booooring. Fine. The \[dish\]." | -2 |
| Rude | "Just order. You're not funny." | "Ooh, ROASTED! Okay, chef! The \[dish\]." He laughs, but his tail stops for a second. | -4 |

**Ordering conversation B (the cheese)**

Cheddar: "Let me guess, you're gonna recommend the \[cheese dish\]. Because I'm a mouse. Named Cheddar. Classic."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "I'd rather know what you actually like." | Stops for a second. "...Huh. Nobody asks that. The \[dish\], I guess." | +3 |
| Playful | "No way. Cheese is for amateurs." | "FINALLY. A chef who gets it." | +4 |
| Straight | "The \[cheese dish\] is popular." | "Yeah, yeah. Everyone says that." | -2 |
| Rude | "You're a mouse. Just eat the cheese." | "Ha. Never heard that one before." | -4 |

**Serving**

- Great: "Oh, chef, you've outdone yourself! I'd give you a standing ovation but I'm very small."
- Okay: "Solid. Seven out of ten. Eight if you laugh at my next joke."
- Burnt: "Ah, I see we're going with charcoal today. Bold. Very bold."
- You served the \[cheese dish\]: "...Wow. Okay. Betrayal. Served on a plate." (-2, but he eats it anyway.)

**Eating chats**

- "Wanna hear a secret? I hid something in this restaurant. Don't look. ...You're gonna look."
- "Rate my chewing. Out of ten. Be honest. Actually don't."
- "I have thirteen siblings. Thirteen. Dinner at my house was a contact sport."

**Leaving**

- "Thank you, thank you, I'll be here all week. Literally. I'm coming back tomorrow."
- "Tip's on the table. It's mostly buttons. Kidding! ...Mostly kidding."

### Stage 2: Sidekick (25 to 49)

**Learning your name and picking a nickname (plays once at 25)**

> "Okay, I've been calling you 'chef' for weeks. What's your actual name? ...\[name\]. Cool. Too normal, though. You need a nickname."

He offers three, and you pick one or refuse:

- "Captain Spatula"
- "The Stove Whisperer"
- "Chef Boss"
- "Just \[name\] is fine" → "Wow. Okay. Fine. \[name\] it is. ...Captain Spatula was RIGHT there."

**Arrival**

- "\[nickname\]! My favorite person in this building. Also the only person in this building. Still counts."
- "I had a dream you burnt my food and I woke up FURIOUS. Don't let it happen in real life."
- Away 3+ real days: "\[nickname\]! I thought you got kidnapped. I was gonna make posters. They were gonna be so good."

**Ordering conversation**

Cheddar: "Okay, new bit. You describe a dish without saying its name, and I guess. Go."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "It's warm, it's cozy, it's perfect for you." | "Aww. Okay, that's cheating, but I'll allow it. The \[dish\]." | +2 |
| Playful | "It's crunchy, it's mysterious, and it is NOT cheese." | "I'll take it, sight unseen. Best bit ever." | +4 |
| Straight | "I'm kind of busy. Just order." | "Ugh. Fine. The \[dish\]." | -1 |
| Rude | "Your bits are getting old." | "...Wow. Okay. The \[dish\]." No laugh this time. | -8 |

**"Surprise me!" (40+, earlier than anyone else)**

> "Surprise me, \[nickname\]. Shock me. Rock my world."

- Favorite: "This is my FAVORITE. Are you reading my diary? I don't have a diary. Are you reading my mind?" (+5)
- &#91;cheese dish\]: "...You had ONE job." (-3, he pouts for the rest of the visit, playfully)
- Anything else: "Ooh, a mystery! I love a mystery." (+2)

**Serving**

- "Thanks, \[nickname\]! This looks great. Like, suspiciously great. Did someone else make this?"

**Eating chat with choices**

Cheddar: "Tell me a joke. Any joke. I've been doing all the work here."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "I'm not funny like you, but I like hearing yours." | "...Okay, that was nice. Don't do that. I'll get emotional in front of my food." | +2 |
| Playful | "Why did the mouse cross the road? To steal my job as the funny one." | Laughs so hard his tail spins. | +4 |
| Straight | "I don't really do jokes." | "Tragic. Truly." | -1 |
| Rude | "You're the joke." | "...Ha. Good one." He leaves early. | -8 |

**Leaving**

- "Bye, \[nickname\]! Don't miss me too much. Actually, miss me a normal amount."

### Stage 3: Real talk (50 to 74)

**Arrival**

- "\[nickname\]! Okay, I have a new bit, but first, how are you? Like, actually?"
- "I sat here because it's the seat closest to the kitchen. ...For the smell. Not because of you. Mostly the smell."
- Away 3+ real days: "Hey. You were gone a while. I, uh... it was weird not coming here. Anyway! Funny story—"
- If you were ever rude to him before: "Remember when you said "\[last\_rude\_line\]"? I laughed. ...It wasn't that funny, actually. Okay! Moving on!" (Plays once. Next choice: apologize for +6, or laugh it off for -3.)

**Ordering conversation**

Cheddar: "Can I tell you something kinda weird? You're the first person who asked what I like instead of just handing me cheese. ...That's it. That's the thing. Ha. Order time!"

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "Of course I asked. You matter to me." | His tail stops. Then goes wild. "...Okay. Okay! Wow. The \[dish\], please. I need to eat my feelings." | +4 |
| Playful | "I'll never hand you cheese. That's my promise." | "Put it in writing. Laminate it." | +3 |
| Straight | "It's just good service." | "Ha. Right. Sure." | 0 |
| Rude | "Don't make it weird." | "...Yeah. Sorry. Forget I said it." He doesn't make a joke for the rest of the visit. | -12 |

**Eating chats (personal, one per visit)**

- Being seen: "At home, if I wasn't being funny, nobody looked at me. Thirteen siblings. You had to earn the spotlight."
  - Warm: "You don't have to earn it here." → Long pause. "...Don't say stuff like that while I'm chewing." (+4)
  - Playful: "Well, here you're the headliner." → "Headliner! Put my name in lights!" (+3)
  - Rude: "Sounds exhausting. You're exhausting." → "...Yeah. I've heard." (-12)
- The quiet: "Can I just... sit here for a minute without doing a bit? Is that allowed?" (Choosing to sit with him silently gives +3. The scene is just the two of you, and his tail slowly curls up.)
- Mabel: "Mabel thinks I'm her grandson. I'm not. I don't correct her. ...Okay, I'm kind of her grandson now."
- Stitches (if Stitches is 50+ too): "That bear with the patches laughed at my joke today. Like, really laughed. He has a great laugh. Does he know that?"

**Leaving**

- "Thanks, \[name\]. ...See? I used your real name. That's how you know I mean it."

### Stage 4: Best friend (75 to 100)

**Arrival**

- "PARTNER! My partner in crime! My co-chef! My—okay I'm out of titles. Hi!"
- "I have a new prank planned and you're helping. Don't argue. You're already in it."
- Away 3+ real days: "You can't just leave! Who's gonna laugh at my jokes? Mabel? She falls asleep halfway through!"

**Ordering conversation**

Cheddar: "Real talk, then bit. Real talk: I'm really glad this place exists. Bit: I'll have one of everything. Kidding. The \[dish\]."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "I'm really glad you exist." | "...You can't follow my real talk with BETTER real talk. That's illegal." | +3 |
| Playful | "One of everything, coming right up. Hope you're hungry." | "Wait, no, I was kidding— ...actually, let's see where this goes." | +3 |
| Straight | "Good to hear. Coming right up." | "Yes, chef!" | +1 |
| Rude | "Can you just order like a normal person?" | "...I thought we were past this." | -12 |

**Joint prank (once at Best friend)**

He asks you to help prank Mabel by hiding her reading glasses on top of her own head. When she comes in, you both watch her search. She finds them and says "Oh, you two," which counts as a kind moment with both of them (+3 each).

**Serving**

- "\[nickname\], you did it again. You're like a food wizard. A fizzard. ...No. Not my best."
- Burnt: "Burnt, but made with love. I can taste the love. It tastes like smoke."

**Eating chats**

- "I don't have to be 'on' here. You know how rare that is?"
- "You know you're my favorite chef in the whole world, right? And I've eaten at, like, four places."

**Leaving**

- "Bye, partner! Don't burn anything while I'm gone. Except maybe Mabel's toast. She likes it that way."

## Negative stages

Where Stitches gets smaller, Cheddar gets sharper, then goes silent. His humor turns into armor. The moment a player should feel it is when the funny mouse stops making jokes.

### -1: Snarky (-1 to -24)

- Arrival: "Oh, look who's working today. Lucky me."
- Ordering: "I'll have the \[dish\]. Try not to set it on fire. Or do. Whatever."
- Serving: "Wow. Food. Incredible."
- No more pranks. The sticky notes stop.
- Playful choice reaction: he almost laughs, then catches himself. "...Not bad."

### -2: Cold (-25 to -49)

- Arrival: "Table for one. Don't bother with the small talk."
- Ordering: "\[dish\]." One word.
- Eating chat (if you walk up): "Did I ask for a visit? Pretty sure I didn't."
- His tail doesn't move once the whole visit.
- Warm choice reaction: "What's this, a bit? You're not funny, remember?" (Throwing your words back at you if you used the "not funny" rude line.)

### -3: Withdrawn (-50 to -74)

He stops coming in and only orders delivery. His orders come with sarcastic notes:

- "Hold the attitude."
- "Five stars for the delivery duck. Zero for the chef."
- "No cheese. You'd know that if you'd listened."

Redemption hook: when you finish his delivery order, you can tuck a note into the bag. A sincere note gives +3. A genuinely funny note gives +5, because a real laugh is the fastest way back to him. His next order's note answers: "...Okay, that one got me. Doesn't mean we're cool."

### -4: Gone (-75 to -100)

On his last delivery order, the slip has one line on it:

> "Knock knock. ...Never mind. You wouldn't get it anyway. —C"

After that he stops ordering. Mabel mentions that her "grandson" doesn't visit as much and seems quieter lately.

**Getting him back from Gone**

Same rule as Stitches: Gone isn't permanent the first time. There are two ways back, and both end in the same scene.

1. **The joke letter.** A "Write a letter" option appears at the counter. You pick the opening (sincere apology) and the closing, which has to be a joke. His reply arrives a few in-game days later: "Your joke was terrible. I laughed anyway. I'll come by."
2. **Through a friend.** Ask Mabel (50+) or Stitches (50+, if they've become friends) to talk to him.
   - Mabel: "Leave it to me, dear. I'll tell him I need help carrying groceries. He can never say no."
   - Stitches: "I can try. He made me laugh when I really needed it. ...Maybe I can do that for him now."

**The comeback scene**

He comes in at closing and stands at the door, tail still.

> **Cheddar:** "So. I had a bit planned for this. A whole thing. I forgot it on the way here."

| You say | He says |
| --- | --- |
| "I'm sorry. I said things that really hurt you." | "Yeah. You did. ...Thanks for saying it without a joke." |
| "I missed your jokes. I missed you." | "...Okay, that's a low blow. In a nice way." |
| "Knock knock." | Long pause. "...Who's there?" You get to finish it, and he laughs for real. |

> **Cheddar:** "Fine. Starting over. Hi, I'm Cheddar. I hate cheese. Nice to meet you."

He returns at 0, at the Showman stage. A second fall to Gone is permanent.

## His big moment: Cheddar cooks for you

The roles flip. You've spent the whole game asking what Cheddar likes, so he cooks *your* favorite food for you and, for once, says something real without a punchline to hide behind. It plays once.

**Setup (earlier, in Best friend stage):** During an eating chat he asks, "Wait. What's YOUR favorite food? You always ask me. Nobody asks you." You pick from a list, and it's saved as `player_favorite`.

**Trigger:** relationship 85+, at least 3 visits at Best friend, `player_favorite` is set, `big_moment_done` is false.

**Staging:** Closing time, after the last customer. No delivery orders that night. The music switches to a goofy, plinky version of the main theme that slowly turns soft.

### Script

Cheddar bursts in wearing a chef's hat that's way too big for him. It covers his eyes.

> **Cheddar:** "Nobody panic! It's me! I'm the chef tonight. You're the customer. Sit. SIT. That's an order, customer."

The player sits at a table, the first time they ever do. Cheddar disappears into the kitchen. Clanging. A small crash. "I'm fine!"

He comes out with a plate of \[player\_favorite\]. It's lopsided, a little burnt on one side, and decorated with a tiny paper flag that says "for \[name\]."

> **Cheddar:** "Okay. So. It's not as good as yours. It's not even as good as your bad days. But I made it."

**Choice 1** (all lead on)

- "You remembered my favorite." → "Obviously. You remember mine. That's how this works."
- "Is this... burnt?" → "It's CHARACTER. I learned that from you."
- Take a bite without saying anything. → He watches you, tail completely still. "...Well?? Say something!"

He sits across from you and takes his hat off. For a second, he doesn't say anything. That silence is the point.

> **Cheddar:** "I'm gonna say something and I'm not gonna make a joke after it. Which is gonna be really hard for me. So just let me get through it."
>
> **Cheddar:** "My whole life, people liked me when I was funny. That's it. That was the deal. Be funny, or be invisible."
>
> **Cheddar:** "And then I come here and you laugh at my jokes, sure. But you also ask how I'm actually doing. And you notice when I'm quiet. And you never, ever give me cheese."
>
> **Cheddar:** "You're the first person who made me feel like I don't have to perform to be worth having around. ...So, thank you. That's it. That's the whole thing."

He holds very still, clearly fighting the urge to add a joke.

**Choice 2**

- "You were always worth having around. Jokes or no jokes." → His eyes get shiny. "...Okay. Okay. I need a minute."
- "You can make a joke now. You've earned it." → "OH THANK GOODNESS. Okay: what do you call a mouse who cooks? ...Me. Tonight. Ha! I'm crying a little."
- "I'm really glad you came into my restaurant." → "...Me too, partner. Me too."

> **Cheddar:** "Okay. Wash the plate yourself, customer. I'm a chef, not a dishwasher. ...Goodnight, \[name\]."

### After the scene

- The "World's Best Chef (don't tell anyone I said that)" sign becomes a permanent decoration in the restaurant.
- His `last_rude_line` is cleared for good. He's let it go.
- A few visits later, he brings up his referral friend (next section).

## Friends, gossip and referral

Unlike Stitches, Cheddar starts the game with a friend: Mabel, who has more or less adopted him as a grandson. He can also become friends with Stitches if both reach 50+. Gossip works the same way as in Stitches' bible: friends bring up how you treated him on their next visit, quoting rude lines exactly.

### Friendships

| Friend | When it starts | What it's like |
| --- | --- | --- |
| Mabel | From the start | She calls him her grandson. He pranks her and she pretends not to notice. |
| Stitches | Both at 50+ | Cheddar makes Stitches laugh for real, and Stitches is the one person Cheddar never does a bit around. |

### Mabel about Cheddar

- Kind: "Cheddar says you're his favorite chef here. He told me three times. He's never said that about anyone, dear."
- Rude:

> "My friend Cheddar told me you said "\[last\_rude\_line\]". He made a joke about it, but I know that boy. He was really hurt by it. You didn't mean it, did you?"

| You say | Mabel says | Effect |
| --- | --- | --- |
| "I didn't. I'll tell him I'm sorry." | "Good. He acts like nothing gets to him. Everything gets to him." | Mabel +2, Cheddar +3 |
| "He laughed, so I thought it was fine." | "Oh, dear. He always laughs. That's how you know." | Mabel 0 |
| "Yeah, I meant it." | "...Well. I'll be eating somewhere quieter for a while." | Mabel -8 |

### Stitches about Cheddar (once they're friends)

- Kind: "Cheddar told me you made him laugh so hard he snorted. He made me promise not to tell anyone. ...I'm only telling you."
- Rude: "Cheddar said you told him "\[last\_rude\_line\]". He said it was fine. ...I don't think it was fine. You didn't mean it, did you?"

### Cheddar about his friends

- You were kind to Mabel: "Grandma Mabel says you sat with her for, like, ten minutes yesterday. You're making the rest of us look bad."
- You were rude to Mabel: "Hey. Mabel told me what you said to her. ...Not cool. She's like a hundred. Be nice to her." This is one of the only times he's completely serious.
- You were kind to Stitches: "Stitches showed me the apron he made you. Okay, I'm jealous. I can't sew. I can make you a sign, though."
- You were rude to Stitches: "Did you say something to Stitches? He's been quiet. Like, quieter. ...Fix it."

### Referral

**Trigger:** relationship 90+, big moment done, then 2 more visits.

> **Cheddar:** "So, I told someone about this place. And they actually listened to me for once. Is it cool if they come by?"

The friend is yours to design. One idea that fits: his favorite sibling out of the thirteen, maybe one who's the total opposite of him (serious, quiet, never jokes). That would let players see where Cheddar comes from.

## Open questions

- [ ] Who is his referral friend? A sibling, or someone else?
- [x] Is the big moment (Cheddar cooks for you) right for him, or do you want a different payoff?
- [x] Is the cheese twist in, or does he actually love cheese?
- [x] Favorite dish: something with a kick, like spicy food? Decide once the menu exists.
- [ ] Should he and Patchy know each other?
- [ ] Any lines or pranks that don't feel like him? Edit them right in this doc.
