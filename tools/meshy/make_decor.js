// Turns the decor concept pictures in design/decor/ into Meshy models.
//
//   node tools/meshy/make_decor.js            every catalogue item with a picture and no model yet
//   node tools/meshy/make_decor.js cafe_bookcase cafe_lemon_tree   just these
//   node tools/meshy/make_decor.js --redo cafe_bookcase            again, even if it has a model
//   node tools/meshy/make_decor.js --restaurant                    the restaurant pieces (see below)
//
// The API key is read from %USERPROFILE%\.meshy_api_key (one line, never in the
// repo). Each item uses <id>.png as the front view, plus <id>_back.png and/or
// <id>_side.png when they're there (Multi-Image to 3D); one picture alone uses
// Image to 3D. The model is saved as design/decor/<id>.glb (the game picks it up
// from there) and Meshy's preview as design/decor/previews/<id>.png. Task ids
// are kept in design/decor/meshy_tasks.json, so a stopped run carries on where
// it was instead of paying twice. About 30 Meshy credits per item.
const fs = require("fs");
const path = require("path");
const os = require("os");

const ROOT = path.resolve(__dirname, "..", "..");
// --restaurant: the restaurant's own pieces (windows, doors, appliances, food)
// from design/restaurant/ instead, sized by design/restaurant/parts.json.
const RESTAURANT = process.argv.includes("--restaurant");
const DECOR = path.join(ROOT, "design", RESTAURANT ? "restaurant" : "decor");
const CATALOGUE = path.join(ROOT, "data", "decor_catalogue");
const PARTS = path.join(ROOT, "design", "restaurant", "parts.json");
const TASKS = path.join(DECOR, "meshy_tasks.json");
const API = "https://api.meshy.ai/openapi/v1";
const SETTINGS = {
	ai_model: "latest",
	should_texture: true,
	texture_resolution: "2k",
	enable_pbr: false,          // The game's toon shader only uses the colour.
	should_remesh: true,        // Light enough to fill a room with them.
	topology: "triangle",
	target_formats: ["glb"],
};
const POLYCOUNT = { small: 6000, normal: 12000 };  // Small: under 0.8 m tall and wide.
const PARALLEL = 4;

function key() {
	const file = path.join(os.homedir(), ".meshy_api_key");
	if (!fs.existsSync(file)) {
		console.error(`No API key: put it on one line in ${file}`);
		process.exit(1);
	}
	return fs.readFileSync(file, "utf8").trim();
}

function catalogueRows() {
	const rows = {};
	if (RESTAURANT) {
		for (const row of JSON.parse(fs.readFileSync(PARTS, "utf8")).items) rows[row.id] = row;
		return rows;
	}
	for (const file of fs.readdirSync(CATALOGUE).filter((f) => f.endsWith(".json"))) {
		for (const row of JSON.parse(fs.readFileSync(path.join(CATALOGUE, file), "utf8")).items || []) rows[row.id] = row;
	}
	return rows;
}

const dataUri = (file) => "data:image/png;base64," + fs.readFileSync(file).toString("base64");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function call(method, url, body) {
	for (let attempt = 0; ; attempt++) {
		const res = await fetch(url, {
			method,
			headers: { Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" },
			body: body ? JSON.stringify(body) : undefined,
		});
		if (res.status === 429 && attempt < 20) {
			await sleep(1000 * Number(res.headers.get("retry-after") || 5));
			continue;
		}
		const text = await res.text();
		if (!res.ok) throw new Error(`${method} ${url.replace(API, "")}: ${res.status} ${text.slice(0, 300)}`);
		return JSON.parse(text);
	}
}

async function make(id, row, tasks) {
	const views = [`${id}.png`, `${id}_side.png`, `${id}_back.png`].map((f) => path.join(DECOR, f)).filter(fs.existsSync);
	const multi = views.length > 1;
	const endpoint = `${API}/${multi ? "multi-image-to-3d" : "image-to-3d"}`;
	let task = tasks[id];
	if (!task || task.endpoint !== endpoint || task.failed) {
		const small = Math.max(Number(row.height || 1), Number(row.size?.[0] || 1)) < 0.8;
		const body = { ...SETTINGS, target_polycount: small ? POLYCOUNT.small : POLYCOUNT.normal };
		if (multi) body.image_urls = views.map(dataUri);
		else body.image_url = dataUri(views[0]);
		const made = await call("POST", endpoint, body);
		task = tasks[id] = { id: made.result, endpoint, views: views.map((v) => path.basename(v)) };
		save(tasks);
		console.log(`${id}: started (${views.length} picture${views.length > 1 ? "s" : ""})`);
	} else console.log(`${id}: carrying on with task ${task.id}`);
	let last = -1;
	for (;;) {
		const got = await call("GET", `${endpoint}/${task.id}`);
		if (got.status === "SUCCEEDED") {
			await download(got.model_urls.glb, path.join(DECOR, `${id}.glb`));
			if (got.thumbnail_url) {
				fs.mkdirSync(path.join(DECOR, "previews"), { recursive: true });
				await download(got.thumbnail_url, path.join(DECOR, "previews", `${id}.png`));
			}
			task.credits = got.consumed_credits;
			task.done = true;
			save(tasks);
			console.log(`${id}: DONE (${got.consumed_credits} credits)`);
			return true;
		}
		if (got.status === "FAILED" || got.status === "CANCELED") {
			task.failed = JSON.stringify(got.task_error || got.status);
			save(tasks);
			console.log(`${id}: FAILED ${task.failed}`);
			return false;
		}
		if (got.progress !== last && got.progress % 25 === 0) console.log(`${id}: ${got.progress}%`);
		last = got.progress;
		await sleep(5000);
	}
}

async function download(url, file) {
	const res = await fetch(url);
	if (!res.ok) throw new Error(`download ${res.status}`);
	fs.writeFileSync(file, Buffer.from(await res.arrayBuffer()));
}

function save(tasks) {
	fs.writeFileSync(TASKS, JSON.stringify(tasks, null, "\t"));
}

const KEY = key();
(async () => {
	const args = process.argv.slice(2);
	const redo = args.includes("--redo");
	const named = args.filter((a) => !a.startsWith("--"));
	const rows = catalogueRows();
	const tasks = fs.existsSync(TASKS) ? JSON.parse(fs.readFileSync(TASKS, "utf8")) : {};
	const todo = (named.length ? named : Object.keys(rows)).filter((id) => {
		if (!rows[id]) return console.log(`${id}: not in the catalogue`), false;
		if (!fs.existsSync(path.join(DECOR, `${id}.png`))) return console.log(`${id}: no picture yet`), false;
		if (fs.existsSync(path.join(DECOR, `${id}.glb`)) && !redo) return false;
		if (redo && tasks[id]) delete tasks[id];
		return true;
	});
	console.log(`${todo.length} to make`);
	let made = 0, failed = 0;
	const queue = [...todo];
	await Promise.all(Array.from({ length: Math.min(PARALLEL, queue.length) }, async () => {
		while (queue.length) {
			const id = queue.shift();
			try { (await make(id, rows[id], tasks)) ? made++ : failed++; }
			catch (e) { failed++; console.log(`${id}: ERROR ${e.message}`); }
		}
	}));
	console.log(`ALL DONE: ${made} made, ${failed} failed`);
})();
