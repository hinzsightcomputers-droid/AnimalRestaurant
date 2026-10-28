# Stitches: Character Bible

Oct 27, 2026 · @Alex

## Who Stitches is

Stitches is the kindest regular in the restaurant and the loneliest. His arc is the heart of the game: the player's kindness slowly turns a bear who apologizes for existing into someone who believes he deserves good things.

**Look.** A small brown bear who looks like a well-loved teddy. Visible hand-sewn patches on his left ear, right elbow and side, in mismatched fabrics. He sewed every one himself. Placeholder: a light brown capsule with a few colored squares on it.

**Backstory.** Other animals have teased him about his patches for as long as he can remember. He has been left out, laughed at and ignored, so he has learned to make himself small. He has no friends and eats alone. Deep down he believes he is broken and a bother to everyone. He is not bitter about it, only sad and quietly hopeful.

**Core truth.** He is the most genuine character in the game. He never lies, never schemes and never says a mean thing about anyone, even people who hurt him.

**Tendencies (things he does, not just says)**

- Always picks the corner table, farthest from everyone.
- Fidgets with his ear patch when nervous. Stops doing it once he's confident.
- Apologizes before asking for anything, and thanks you more than once.
- Wipes his own table before leaving in early stages, because he doesn't want to make work for you. Once he trusts you, he lets you clean it.
- Leaves a tip that's a little too big, as if paying for the trouble of being there.
- Carries a small sewing kit. Later in the arc he mends things around the restaurant.
- Remembers every kind thing you've said and brings them up later.

**Voice rules**

| Stage | How he talks |
| --- | --- |
| Nervous | Short sentences, lots of "...", "sorry", "um". Asks permission. Assumes he's a bother. |
| Warming | Tries a small joke, then checks if it landed. Starts using your name. |
| Opening up | Full sentences. Talks about sewing. Asks about you and remembers your answers. |
| Confident | Warm and gently teasing. Says what he feels plainly. Still humble, never cocky. |
| Any negative stage | Never angry or cruel. He gets quieter and sadder, and blames himself before he blames you. |

## Relationship system

Relationship runs from -100 to 100, with four friendly stages and four disliking stages. Every regular uses this scale; Stitches' stages are named below.

| Range | Stage | What unlocks or changes |
| --- | --- | --- |
| 75 to 100 | 4. Confident | "Surprise me" orders. Gift scene at 85+. Can make a friend and recommend them. |
| 50 to 74 | 3. Opening up | Personal eating-time chats. Talks about sewing, asks about you. |
| 25 to 49 | 2. Warming | Learns and uses your name. "What do you recommend?" from 40+. |
| 0 to 24 | 1. Nervous | Basic orders and small talk. Where he starts. |
| -1 to -24 | -1. Confused | Wonders what he did wrong. |
| -25 to -49 | -2. Hurt | Quiet, avoids eye contact, no small talk. |
| -50 to -74 | -3. Withdrawn | Stops coming in. Only orders through delivery. |
| -75 to -100 | -4. Gone | Stops ordering entirely. Leaves a goodbye note. |

**Four response options every conversation**

Each player choice is tagged with a tone: warm, playful, straight or rude. The rude option is always last in the list so it never gets picked by accident.

| Stage | Warm | Playful | Straight | Rude |
| --- | --- | --- | --- | --- |
| Nervous | +4 | +1 or -1 (he may think you're laughing at him) | -1 | -8 |
| Warming | +3 | +2 | 0 | -8 |
| Opening up | +3 | +3 | +1 | -10 |
| Confident | +2 | +3 (he loves teasing now) | +1 | -12 |
| Any negative stage | +2 | 0 | +1 | -6 |

Rude hurts more the closer you are, because he trusted you. Climbing back from negative is slow on purpose: he forgives, but he's wary.

**Rules that keep the dark side intentional**

- One rude choice can never drop him more than one stage in a single visit.
- He can't go below 0 unless you've picked rude at least 3 times in a row with him (tracked as `rude_streak`). Any non-rude choice resets the streak.
- Reaching Withdrawn or Gone takes many visits of deliberate cruelty. No player gets there by accident.
- Every rude line you choose is saved (`last_rude_line`) so he, or later his friends, can quote it back to you.

## Dialogue by stage

Each stage has its own pool of lines, so his voice literally changes as he grows. \[dish\] is filled in from the menu once it exists; \[name\] only appears once he knows the player's name. Each ordering conversation shows the four choices in this order, rude last.

### Stage 1: Nervous (0 to 24)

**Arrival**

- First visit ever: "Oh... um. Hi. Is it okay if I sit here? In the corner? I won't be in the way."
- "Sorry. Hi. I'm back. If that's okay."
- "Um... is the corner table free? It's fine if it's not."
- "Hello... I hope it's not too busy. I can come back later if it is."
- Away 3+ real days: "Oh... you're open. I came by a few times. It was closed. I thought maybe... never mind. I'm glad you're okay."
- Last meal was burnt: "Last time was... it was fine! Really. I ate all of it."
- Last meal was great: "I kept thinking about my last meal here. Is that weird? Sorry."

**Ordering conversation A**

Stitches: "Um... I'll just have whatever's easiest for you. I don't want to make extra work."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "You're never extra work. Order what you really want." | "...Really? Okay. Then the \[dish\]. Thank you. Thank you." | +4 |
| Playful | "Easiest for me is nothing. Want a bowl of air?" | Lands: "Ha... that was funny. I think." Misses: "Oh. Sorry. I'll pick something." | +1 / -1 |
| Straight | "Just tell me what you want." | "S-sorry. The \[dish\]. Sorry." | -1 |
| Rude | "Then hurry up and pick. People are waiting." | He grips his ear patch. "...Right. Sorry. The \[dish\]." | -8 |

**Ordering conversation B**

Stitches: "Sorry, I'm slow to decide. Everything sounds nice. That's a good problem, I guess."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "Take all the time you need. I'll wait." | "...Nobody ever says that to me." | +4 |
| Playful | "Close your eyes and point at the menu." | "Okay... oh! That's a good one, actually." | +1 |
| Straight | "I'll come back in a minute." | "Okay. Sorry." | -1 |
| Rude | "Seriously? It's not that hard." | "...I know. I'm sorry." | -8 |

**Ordering conversation C (his patches)**

Stitches: "Sorry, my paw's stitching came loose again. Please don't mind it."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "Your stitching is really neat. Did you do it yourself?" | Long pause. "...You noticed? I did. Thank you." | +5 |
| Playful | "It matches the tablecloth. Very stylish." | "Oh... does it? I didn't plan that." | +1 |
| Straight | "No problem. What can I get you?" | "The \[dish\], please." | 0 |
| Rude | "Just don't get stuffing in the food." | He goes very still. "...I'll be careful." | -8 |

**Serving**

- Great: "Oh... it's beautiful. You made this? For me? Thank you. Really."
- Okay: "Thank you so much. It smells really nice."
- Burnt: "It's... it's perfect. Thank you." He eats every bite and never complains.

**Eating chats (walk up to his table)**

- "Oh! Hi. Is something wrong? Am I eating too slow?"
- "It's quiet in here today. I like quiet. ...I'm used to it."
- "Sorry if I'm staring at the kitchen. It's nice watching someone make something with care."

**Leaving**

- "Thank you. Sorry for the trouble. I wiped the table already."
- "I'll... maybe come back? If that's okay."

### Stage 2: Warming (25 to 49)

**Learning your name (plays once, when he first reaches 25)**

> "Can I ask your name? You know mine. It feels rude that I don't know yours." ... "\[name\]. That's a nice name. I'll remember it. I promise."

**Arrival**

- "Hi, \[name\]. ...I practiced saying your name on the way here. Is that weird? Don't answer that."
- "I'm back! I mean. Hi. A normal amount of excited."
- Away 3+ real days: "\[name\]! You're back. I walked past every day, just in case."
- Last meal was great: "I told my reflection about your cooking. It was the only one listening. Ha. That was a joke."

**Ordering conversation**

Stitches: "I tried to guess what I'd order on the way here. I changed my mind three times."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "Whatever you pick will be the right choice." | "...You always say nice things. I'm not used to it yet." | +3 |
| Playful | "Let me guess for you. I'm amazing at guessing." | Laughs. "You'll just pick what you're best at making! ...That was a joke. Was it okay?" | +2 |
| Straight | "What did you land on?" | "The \[dish\], please." | 0 |
| Rude | "Can you not ramble? I'm busy." | "Oh... right. Sorry." He doesn't look up again this visit. | -8 |

**"What do you recommend?" (40+)**

> "Um, \[name\]? What would you recommend? You'd know better than me."

- You pick his favorite: "This is my favorite. How did you know? ...Did you remember?" (+5)
- You pick his disliked dish: "Oh! It's good. I'm going to eat all of it." He would never admit it, but he quietly leaves a few bites. Observant players will notice. (0)
- Anything else: "I'll trust you. You haven't been wrong yet." (+1)

**Serving**

- "Thank you, \[name\]. It looks so good. I'm going to eat it slowly so it lasts."
- "You remembered I like it warm. ...Or you didn't, and I'm just lucky. Either way."

**Eating chat with choices**

Stitches: "Can I tell you something? This is the only place where nobody stares at my patches."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "They're part of you. I like them." | He touches his ear patch, but not nervously this time. "...Okay." | +3 |
| Playful | "Everyone's too busy staring at my cooking." | "Ha! That's true. It's very stare-able." | +2 |
| Straight | "Glad you feel comfortable here." | "I really do." | 0 |
| Rude | "Probably because you hide in the corner." | "...Yeah. Probably." | -8 |

**Leaving**

- "See you soon, \[name\]. I still wiped the table. Old habits."

### Stage 3: Opening up (50 to 74)

**Arrival**

- "\[name\]! Guess what. I finished a new patch. Look, it has little stars on it."
- "I saved the corner table. ...Okay, nobody else ever takes it. But I saved it anyway."
- Away 3+ real days: "You're back! I missed this place. I missed... you know. Talking to you."
- Last meal was burnt: "Last time was a little crispy. I'm only telling you because you said I could be honest with you."

**Ordering conversation**

Stitches: "How's your day been? You always ask about mine. It's your turn."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "Better now that you're here." | "You can't just say things like that. Now I'll be smiling all day." | +3 |
| Playful | "A customer asked about my day. Very suspicious." | Laughs for real. "Okay, okay! I'll order! The \[dish\]." | +3 |
| Straight | "Busy, but good." | "I'm glad. Don't work too hard, okay?" | +1 |
| Rude | "Why do you even care?" | "...Because I do. Sorry. I'll just order." | -10 |

**Eating chats (personal topics unlock here, one per visit)**

- His ear: "When I was little, my ear got torn off in a fight I didn't start. I sewed it back on myself. It came out crooked. It's still crooked."
  - Warm: "You fixed it yourself. That's brave." → "Nobody ever called it brave. They called it ugly." (+3)
  - Playful: "Crooked ears are in this season." → "Then I'm very fashionable." (+3)
  - Rude: "Yeah, I can tell." → He lets go of his ear and stares at his plate. (-10)
- Big question: "Do you ever feel like you're too much? Or not enough? ...Sorry. That's a big question for lunch."
- Sewing: "I could fix that loose button on your apron. If you want. I'm good at fixing things. Just not myself. ...That was a joke! Mostly."
- Mabel (if Mabel is 50+ too): "The tortoise lady, Mabel, said hello to me today. She asked if I made my patches. She said they're lovely." This starts their friendship (see Friends section).

**Leaving**

- "Can I leave the table for you this time? ...I trust you not to mind." This is the first visit he doesn't wipe it.

### Stage 4: Confident (75 to 100)

**Arrival**

- "\[name\]! I'm here! Your favorite customer! ...Is that too much? No. I'm owning it."
- "I sat at a middle table today. In the middle. Where people can see me. Are you proud of me? You can say yes."
- Away 3+ real days: "There you are! I was about to sew a 'missing chef' poster."

**"Surprise me!"**

> "Surprise me. I trust you completely."

- Favorite: "You KNOW me. This is the best day."
- Disliked: He finally admits it. "Okay. I need to confess something. I've never liked this one. I just never wanted to hurt your feelings." The player gets a new choice to laugh about it together. This only happens here, because he finally feels safe being honest.
- Anything else: "New! I like new things now. That's new too."

**Ordering conversation**

Stitches: "I'm going to order something I've never tried. Old me would never. New me is brave. Mostly."

| Tone | You say | He says | Change |
| --- | --- | --- | --- |
| Warm | "I'm really proud of you, you know." | "...Don't make me cry before I've even eaten." | +2 |
| Playful | "New you better tip less than old you." | "Never! Old me and new me agree on tipping." | +3 |
| Straight | "Go for it. I'll make it good." | "I know you will." | +1 |
| Rude | "Nobody cares, just order." | The ear fidget comes back for the first time in weeks. "...Oh. Okay." | -12 |

**Serving**

- "\[name\], this looks amazing. You always make me feel like I'm worth the effort."
- Burnt: "You burnt the edge a little. I'm still eating all of it. I'm just letting you know I noticed." (He can tease you now.)

**Eating chats**

- "I used to think my patches made me broken. Now I think they just make me... me."
- "I said hi to someone at the park today. First. I went first. My heart was pounding." (Sets up his referral, see Friends section.)
- "Do you need anything mended? I mean it. You've fixed a lot for me. Let me fix something for you."

**Leaving**

- "Bye, \[name\]! Same time tomorrow? I'm not asking. I'm telling you."
- He waves from the door, then waves again, then a third time.

## Negative stages

Stitches never turns mean. Where another character might get angry, he gets smaller, and that is what makes being cruel to him feel heavy. Every negative stage can be climbed out of. Gone is the hardest: you can't reach him directly anymore.

### -1: Confused (-1 to -24)

- Arrival: "Hi... um. Did I do something wrong last time? You can tell me. I'll fix it."
- Arrival quoting you: "I keep thinking about when you said "\[last\_rude\_line\]". ...I'm sure you were just busy."
- Ordering: "I'll be quick. I won't bother you."
- Serving: "Thank you. Sorry."
- Warm choice reaction: "...Oh. Okay. Thank you." He sounds like he wants to believe it.

### -2: Hurt (-25 to -49)

He stops making small talk. He orders without looking up, eats fast, and his tip shrinks to the exact amount.

- Arrival: "...Hi."
- Ordering: "The \[dish\]. Please."
- Eating chat (if you walk up): "Did you need something? I'm almost done. I'll go soon."
- Leaving: He wipes the table again, even harder than in stage 1.
- Warm choice reaction: "Why are you being nice now?" A pause. "...Sorry. That was rude of me." Even hurt, he apologizes to you.

### -3: Withdrawn (-50 to -74)

He stops coming in. His name only shows up on delivery orders, so the player sees "Order for: Stitches" and has to cook for someone who won't face them.

- Delivery note on his order: "Corner table person. No need to rush. Sorry."
- Redemption hook: a "write a note" option appears when you finish his delivery order. A kind note gives +5 and his next order's note answers it: "Thank you for the note. I read it a few times." Enough kind notes bring him back through the door.

### -4: Gone (-75 to -100)

On his final delivery order, the delivery character hands you a folded note instead of a payment slip:

> "I won't bother you anymore. Thank you for all the food. You're a really good cook. I hope your restaurant is always busy. — S."

After that he stops ordering. Mabel or Cheddar may mention that the bear with the patches doesn't come around anymore. No one blames you out loud, which is worse.

**Getting him back from Gone**

There are two ways back. Both end in the same apology scene.

1. **The apology letter.** After he's gone, a "Write a letter" option appears at the counter. The delivery character takes it to him. He doesn't answer right away; it takes a few in-game days. If the letter is sincere (all warm choices when writing it), his reply arrives: "I got your letter. I read it a lot of times. ...I'll come by. Just once."
2. **Through a friend.** If Mabel or Patchy is his friend, you can ask them about him during their visit. They agree to talk to him, but only if your relationship with *them* is good (Mabel 50+, Patchy 50+).
   - Mabel: "Oh, dear. I'll bring him some tea and have a word. He's never been able to say no to me."
   - Patchy: "You want me to talk to him? ...Okay. But if you hurt my guy again, we're done. For real."

If Stitches never got close enough to make friends before you drove him away, the letter is the only way back. That's the price of being cruel to someone who has nobody.

**The apology scene**

He comes in at closing, like the gift scene, but he stands by the door instead of sitting.

> **Stitches:** "Hi. ...I almost didn't come in. That's twice now, at this restaurant."

| You say | He says |
| --- | --- |
| "I'm so sorry. You didn't deserve any of it." | "...I kept thinking it was my fault. That I was too much." |
| "I was cruel to you. There's no excuse." | "Thank you for not making one." |
| "I want to start over, if you'll let me." | "Starting over is okay. I'm good at fixing things." He touches his ear patch. |

> **Stitches:** "I forgive you. I think I already did, a little, before I even walked in. ...Can I have the corner table? Just for now."

He returns at relationship 0, stage Nervous, with all his early nervousness back. `rude_streak` resets. If you are rude to him again after this, his drop to Gone is permanent.

## The gift scene

The emotional payoff of his whole arc: Stitches gives you a patchwork apron he sewed himself and tells you that your kindness changed his life. It plays once and never repeats.

**Trigger:** relationship 85+, at least 3 visits while Confident, `gift_given` is false.

**Staging:** It happens at closing, after the day's last customer leaves. No delivery orders that evening. The lights dim, the music drops to a soft version of the main theme, and the camera moves in close. There is no rude option in this scene. It has been earned.

### Script

Stitches comes in holding a bundle wrapped in brown paper. For the first time in weeks, he is fidgeting with his ear patch.

> **Stitches:** "Hi, \[name\]. Sorry. I know you're closing. I'm nervous. ...I'm doing the ear thing again. I haven't done that in a long time."
>
> **Stitches:** "I made you something. It took me a while. Every night for a few weeks."

He unwraps it: a patchwork apron in mismatched fabrics.

> **Stitches:** "Every patch is from something. The blue one is from my old blanket. This one with the stars, you remember that one? And this one is from the scarf I wore the first day I came here. I was so scared that day. I almost didn't come in."

**Choice 1** (all three keep the scene going; each gets its own short reply)

- "Stitches... it's beautiful." → "You really think so? ...You always say things like you mean them."
- "You made all of this for me?" → "Of course for you. Who else?"
- "I'm going to wear it every day." → "Every day? Okay. Now I have to make sure it's sturdy."

> **Stitches:** "Before I found this place, I ate alone every day. I thought that's just what I was. Someone people put up with."
>
> **Stitches:** "And then you were nice to me. Not once. Every time. Even when I was weird. Even when I said sorry too much."
>
> **Stitches:** "You never laughed at my patches. You asked about them. Nobody had ever done that."
>
> **Stitches:** "I sat at a middle table last week. I said hi to a stranger at the park. I like myself now. Most days. ...That's because of you."
>
> **Stitches:** "You changed my life, \[name\]. I just wanted you to know."

**Choice 2**

- "You did all of that. I just made the food." → "Maybe. But you made it like I mattered."
- "Okay, now YOU'RE going to make ME cry." → He laughs through tears. "Good. Then we're even."
- "You're my favorite customer. You always were." → A long pause. He hugs you (a simple lean-in animation is enough for placeholder art).

> **Stitches:** "Okay. I'm going to go before I cry in your restaurant. ...Too late. Goodnight, \[name\]."

He wipes his eyes with his patched arm, waves at the door, waves again, and leaves.

### After the scene

- The apron becomes something the player can wear (later, once customization exists).
- Other regulars notice it. Mabel: "What a lovely apron, dear. Did that sweet bear make it? He has such talented paws."
- A few visits later, he brings up the stranger from the park. That starts his referral (next section).

## Friends, gossip and referrals

Stitches starts the game with zero friends, so at first nobody speaks up for him or about him. That silence is intentional. His first friendships form through the player, and once they do, the gossip system turns on for him.

### How gossip works (all characters)

- Each regular has a `friends` list.
- When you cross a stage boundary with someone, or pick a rude line with them, a gossip event is queued for each of their friends (`pending_gossip`).
- The friend brings it up once, on their next visit, during ordering or eating. Rude gossip quotes the exact line you said.
- Your response to the friend matters to both characters. Apologizing gives +3 to the hurt character as well, because the friend passes it on.

### Stitches' first friend: Mabel

When both Stitches and Mabel reach 50+, Mabel says hello to him (his stage 3 chat). From then on they are on each other's `friends` list. Your kindness is literally what introduced them.

**Mabel, when you've been kind to Stitches**

- "Stitches told me you remembered his favorite dish. He talks about you like you hung the moon, dear."

**Mabel, when you've been rude to Stitches**

> "Stitches told me you said "\[last\_rude\_line\]". He was really hurt by it, dear. You didn't mean it, did you?"

| You say | Mabel says | Effect |
| --- | --- | --- |
| "I didn't. I feel awful. I'll make it right." | "I knew it. Tell him yourself, he'll forgive you in a heartbeat." | Mabel +2, Stitches +3 |
| "I was having a bad day." | "We all do. But he's had more bad days than most." | Mabel 0 |
| "Yeah, I meant it." | Long silence. "...I see." | Mabel -8, she starts sitting farther from the counter |

**Stitches, when you've been kind to Mabel**

- "Mabel says you're her favorite chef here. ...I told her I said it first."

**Stitches, when you've been rude to Mabel**

- "Mabel said you were short with her yesterday. That's not like you. ...Is everything okay?" He worries about you instead of scolding you. That's who he is.

### Referral: Patchy, his friend from the park

Some characters can only ever arrive through a referral and never show up on their own (`referral_only`).

**Trigger:** relationship 90+, gift scene done, then 2 more visits.

> **Stitches:** "I made a friend. A real one. His name is Patchy. He's a duck and he's so cool, \[name\], you have no idea. ...I told him about this place. About you. Is it okay if he comes by?"

**Who Patchy is.** A red duck with an eye patch and the exact opposite of Stitches: confident, charismatic, always dressed sharp. He cares a lot about looking good and has great taste. When Stitches nervously said hi at the park, Patchy looked at his patches and saw style, not damage. He thinks Stitches is the coolest-looking guy in town, and he tells him so constantly.

**How they met (Stitches tells you this):** "I said hi first. He looked at my patches and I got ready for the joke. And he said, 'Custom? That's iconic.' Nobody has ever called me iconic, \[name\]."

**Why they work together:** Patchy has an eye patch too. Stitches hides his patches; Patchy shows his off. Stitches is learning confidence from Patchy, and Patchy, who acts like nothing gets to him, is learning from Stitches that it's okay to be soft.

**Patchy's first visit**

> "So YOU'RE the chef. Stitches talks about you all the time. Says you're the reason he talks to people now. ...Had to see for myself. Nice place. Could use better lighting, but I'll allow it."

**Patchy as Stitches' friend (gossip)**

- You've been kind to Stitches: "My guy showed me the apron he made you. You better be wearing it. ...You are. Respect."
- You've been rude to Stitches: "Yo. Stitches told me you said "\[last\_rude\_line\]". He tried to play it off, but I know him. That hurt him. You didn't mean it, right?" Unlike Mabel, Patchy holds a grudge: doubling down gives Patchy -12.

Patchy gets his own full character bible next, written to the same depth as this one.

## Data fields and open questions

These fields get added to every regular's data on top of the ones in the original plan, so Claude Code can build the system once for all characters.

| Field | Type | What it's for |
| --- | --- | --- |
| relationship | number, -100 to 100 | Replaces the old 0 to 100 range |
| rude\_streak | number | Rude choices in a row; must reach 3 before going below 0 |
| last\_rude\_line | text | Quoted back by him and his friends |
| tone\_reactions | table per stage | The warm/playful/straight/rude values above |
| friends | list of ids | Who hears about how you treat this character |
| pending\_gossip | list | Events a friend will bring up next visit |
| referral\_only | true/false | Never visits unless someone recommends them |
| referred\_by | id | Who introduced them |
| gift\_given | true/false | Gift scene has played |
| seen\_lines | list of ids | So the same line doesn't repeat too soon |

**Open questions for you**

- [x] Is Gone permanent? No. Win him back with an apology letter or through Mabel or Patchy. A second fall to Gone is permanent.
- [x] Who is his friend from the park? Patchy, a red duck.
- [x] Gift: the patchwork apron.
- [x] He hides his dislike of a dish until Confident.
- [ ] Any lines that don't sound like him? Edit them right in this doc.
