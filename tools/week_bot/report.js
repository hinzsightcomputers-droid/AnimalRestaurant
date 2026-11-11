// Usage: node tools/week_bot/report.js [out folder]
// Reads the week bot's day logs (d<N>_log.txt, d<N>_raw.txt) and writes
// report.md beside them: money and stars per day, what it bought, lines said
// too often, slow cooking steps, and anything that went wrong.
// Default folder: $WEEK_BOT_DIR/out, else $TEMP/dinner-time-week-bot/out.
// Note: the bot cooks perfectly and never dawdles, so its earnings are a
// ceiling, not what a new player makes.
const fs = require("fs");
const path = require("path");

const base = process.env.WEEK_BOT_DIR || path.join(process.env.TEMP || ".", "dinner-time-week-bot");
const dir = process.argv[2] || path.join(base, "out");
const REPEAT_AT = 3; // A line said this many times in a day is listed.

const days = fs.readdirSync(dir)
	.map((f) => /^d(\d+)_log\.txt$/.exec(f))
	.filter(Boolean)
	.map((m) => Number(m[1]))
	.sort((a, b) => a - b);
if (days.length === 0) {
	console.error(`no day logs in ${dir}`);
	process.exit(1);
}

const field = (text, re) => (re.exec(text) || [])[1] || "";
const rows = [];
const sections = [];

for (const d of days) {
	const log = fs.readFileSync(path.join(dir, `d${d}_log.txt`), "utf8");
	const lines = log.split("\n");
	const find = (tag) => lines.find((l) => l.includes(tag)) || "";
	const summary = find("] SUMMARY ");
	const end = find("] END OF RUN");
	const start = find("in the restaurant:");
	const bought = find("] BOUGHT ").replace(/^.*?BOUGHT /, "");
	rows.push({
		d,
		date: field(find("DAY RUN"), /date (\S+ \(\w+\))/),
		start: field(start, /money \$(\d+)/),
		served: field(summary, /Customers served: (\d+)/),
		earned: field(summary, /Earned today: \$(\d+)/),
		tips: field(summary, /tips \$(\d+)/),
		cooking: field(summary, /Average cooking: ([^/]+?) \//),
		wait: field(summary, /Average wait: (\S+)/),
		reactions: field(summary, /Reactions: ([^/]+?) \//),
		left: field(end, /money \$(\d+)/),
		stars: field(end, /stars (\d+)/),
		menu: field(end, /menu (\d+)/),
		community: field(end, /community (\d+)/),
		decor: field(end, /decor (\d+)/),
		finished: end !== "" && !log.includes("OUT OF TIME"),
	});

	const out = [`## Day ${d}`];
	out.push(`**Bought:** ${bought || "(no shop: the day didn't finish)"}`);

	// Lines said too often (who | what), and messages repeated.
	const counts = new Map();
	for (const l of lines) {
		const m = /\] BOX (.*)$/.exec(l);
		if (m && !m[1].startsWith("Drinks | ")) counts.set(m[1], (counts.get(m[1]) || 0) + 1);
	}
	const repeats = [...counts].filter(([, n]) => n >= REPEAT_AT).sort((a, b) => b[1] - a[1]);
	out.push("", `**Lines said ${REPEAT_AT}+ times:** ${repeats.length ? "" : "none"}`);
	for (const [text, n] of repeats) out.push(`- ${n}x ${text.slice(0, 160)}`);

	// Cooking steps: average seconds per step, slowest first.
	const steps = new Map();
	for (const l of lines) {
		const m = /cook step '(.+)' took ([\d.]+)s/.exec(l);
		if (m && m[1] !== "(between steps)") {
			const s = steps.get(m[1]) || [];
			s.push(Number(m[2]));
			steps.set(m[1], s);
		}
	}
	const slow = [...steps].map(([k, v]) => [k, v.reduce((a, b) => a + b, 0) / v.length, v.length])
		.sort((a, b) => b[1] - a[1]).slice(0, 5);
	if (slow.length) {
		out.push("", "**Slowest cooking steps (average, game seconds):**");
		for (const [k, avg, n] of slow) out.push(`- ${k}: ${avg.toFixed(1)}s (${n}x)`);
	}

	// Trouble: stuck, unreachable, pauses, out of time, script errors.
	const trouble = lines.filter((l) => /STUCK\?|can't reach|PAUSED|OUT OF TIME|decor: no room/.test(l)).map((l) => l.trim().slice(0, 200));
	const rawPath = path.join(dir, `d${d}_raw.txt`);
	if (fs.existsSync(rawPath)) {
		const raw = fs.readFileSync(rawPath, "utf8").split("\n");
		for (let i = 0; i < raw.length; i++) {
			if (/SCRIPT ERROR|^ERROR:/.test(raw[i])) trouble.push(`${raw[i].trim().slice(0, 160)} ${(raw[i + 1] || "").trim().slice(0, 120)}`);
		}
	}
	const unique = [...new Set(trouble)];
	out.push("", `**Trouble:** ${unique.length ? "" : "none"}`);
	for (const t of unique.slice(0, 25)) out.push(`- ${t}`);
	if (unique.length > 25) out.push(`- ...and ${unique.length - 25} more`);
	sections.push(out.join("\n"));
}

const table = [
	"| Day | Date | Start $ | Served | Earned (tips) | Cooking | Wait | Reactions | $ after shop | Stars | Menu | Community | Decor | Finished |",
	"|---|---|---|---|---|---|---|---|---|---|---|---|---|---|",
	...rows.map((r) => `| ${r.d} | ${r.date} | ${r.start} | ${r.served} | ${r.earned} (${r.tips}) | ${r.cooking} | ${r.wait} | ${r.reactions} | ${r.left} | ${r.stars} | ${r.menu} | ${r.community} | ${r.decor} | ${r.finished ? "yes" : "**no**"} |`),
];
const report = [
	"# Week bot report",
	"",
	`Days ${days[0]} to ${days[days.length - 1]}, written ${new Date().toISOString().slice(0, 16).replace("T", " ")}. The bot cooks perfectly and serves at once, so money is a ceiling.`,
	"",
	...table,
	"",
	sections.join("\n\n"),
	"",
].join("\n");
fs.writeFileSync(path.join(dir, "report.md"), report);
console.log(`wrote ${path.join(dir, "report.md")}`);
console.log(table.join("\n"));
