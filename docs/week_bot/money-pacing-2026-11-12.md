# Money pacing: shop prices against a day's pay (2026-11-12)

Short answer: the 1-star shop holds about $1,570 of things by day 7, but the
bot earned $3,413 in that week, so it ended with $1,873 it couldn't spend.
This branch makes pay 14% lower and the big kitchen upgrades dearer, so the
bot ends week 1 with about $1,100 and a real player with a few hundred. That
leftover is meant for the stage 2 fee, which is the planned big spend.

## Where the money goes now (before this branch)

What the shop has by the end of day 7 (data/upgrades.json "arrives"):

| What | Count | Cost |
|---|---|---|
| Upgrades (Sharp Knife to Second Oven) | 8 | $485 |
| Dishes (Cherry Pie to Mochi) | 7 | $470 |
| Drinks (Pupsi to Matcha Latte) | 12 | $420 |
| Decor, tier 1, one of each | 11 | $195 |
| **Total** | | **about $1,570** |

Days 8–12 add about $810 more (4th stove and board, Welcome Sign, 5 dishes,
2 drinks). After day 12 only decor is left: second copies and tier 2+.

What a day pays: about $490 for the bot (24–29 served, all Delighted, so 150%
of price; tips are about half). A real player is lower: Happy pays 120%
instead of 150%, and fewer customers get served. A guess is 60–70% of the
bot, so about $300–340 a day before this branch.

## What this branch changes

Dish and drink prices live in design/menu/, which this worker can't commit,
so the changes are in data/ only.

1. **Pay: `pay_scale` 0.7 to 0.6** (data/service.json). Every bill is 14%
   smaller: the bot about $420 a day, a real player about $260–290.
2. **Bigger upgrades cost more** (data/upgrades.json). The first ones stay
   cheap so day 1 still buys something; the ones that change the kitchen or
   the money become things to save up for:

| Upgrade | Arrives (end of day) | Was | Now |
|---|---|---|---|
| Sharp Knife, Ticket Rail, Comfy Cushions | 1–2 | $30–45 | same |
| Steady Stove | 4 | $60 | $90 |
| Third Chopping Board | 3 | $60 | $100 |
| Third Stove | 2 | $70 | $120 |
| Tip Jar | 6 | $80 | $150 |
| Second Oven | 5 | $100 | $180 |
| Fourth Chopping Board | 9 | $110 | $200 |
| Fourth Stove | 8 | $120 | $220 |
| Welcome Sign | 9 | $100 | $200 |

The week-1 shop goes from about $1,570 to about $1,840, days 8–12 from about
$810 to about $1,100.

## What it should come to (estimate)

| | Week 1 earned | Week 1 shop | Left at day 7 | Left at day 12 |
|---|---|---|---|---|
| Bot, before | $3,413 | $1,570 | $1,873 (seen) | about $3,500 |
| Bot, this branch | about $2,930 | about $1,840 | about $1,100 | about $2,100 |
| Real player, this branch | about $1,900 | about $1,840 | about $100 | about $500 |

So a real player can't buy everything the day it arrives and has to choose,
and still clears the shop by about day 12. The bot (a perfect cook) still
piles up money, which is fine: it's a ceiling.

## Rerun with this branch (days 1–3)

Run 2026-11-12 on this branch (fresh save, same bot). Before = the
2026-11-11 run.

| Day | Served (before) | Earned (before) | $ after shop (before) | Bought this run |
|---|---|---|---|---|
| 1 | 23 (24) | $389 ($466) | $89 ($156) | Ticket Rail, Sharp Knife, 2 drinks, Cherry Pie, 6 decor |
| 2 | 25 (27) | $412 ($528) | $161 ($434) | Comfy Cushions, Third Stove ($120), 2 drinks, Soft Pretzel, 3 decor |
| 3 | 24 (26) | $398 ($462) | $314 ($706) | Third Chopping Board ($100), 2 drinks, Croissants, 1 decor |

Earned is 18% lower over 3 days (14% from pay, the rest is a few fewer
customers, which is chance). The leftover after day 3 is less than half of
before. The bot still buys everything in stock each day, but with $89–314
left instead of $156–706.

Seen on the way, not changed: by the end of day 3 this run had menu 19/18,
community 53/50 and decor 25/25, so star 2 was ready on day 3 (the four new
tier-1 decor pieces made decor reachable with one of each). The plan was
about the end of week 1. That's your call (the star-2 bar).

## Stage fees (a proposal, not changed)

The stages aren't built yet and their fees are yours to set. With this
branch, once the shop is cleared (about day 12) a real player saves about
$1,800–2,000 a week, more once stages add customers. If each stage should
take a week or two of saving after its star:

| Stage | Star (GDD guess) | Fee now | Suggested |
|---|---|---|---|
| 2 | 2 (week 1–2) | $500 | $800 |
| 3 | 3 (week 3–4) | $1,500 | $3,000 |
| 4 | 4 (week 6–8) | $4,000 | $7,000 |
| 5 | 5 (month 3–4) | $10,000 | $15,000 |
| 24-hour café | after 5 | $15,000 | $25,000 |

At $500, stage 2 would be paid for the day star 2 arrives even by a real
player, and stage 3 at $1,500 would wait on the star, not the money.

## Other ways to go (not done)

- **More to buy at 1 star:** second copies of decor already soak up about
  $195 and help star 2; a "Buy another" hint in the shop would point players
  at it. New dishes or drinks need menu data in design/.
- **Lower pay further (0.5):** would make week 1 tight for a real player
  (about $1,600 against a $1,840 shop) and the shop the only goal; it leaves
  little for stages.
- **Dearer dishes and drinks:** the drinks are $30 each and come 2–3 a day,
  so they're the easiest money sink to grow; needs design/menu/drinks.json.
