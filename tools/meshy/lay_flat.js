// Lays a Meshy model flat in its own .glb: for a picture drawn from straight
// above (a face breakfast, a tray of cookies) Meshy builds the thing standing
// up, facing forward. This wraps the scene in a node turned -90° about x, so the
// front ends up facing the sky, wherever the game shows the model.
//
//   node tools/meshy/lay_flat.js design/restaurant/big_breakfast.glb [more.glb ...]
const fs = require("fs");

for (const file of process.argv.slice(2)) {
	const glb = fs.readFileSync(file);
	if (glb.readUInt32LE(0) !== 0x46546c67) throw new Error(`${file}: not a .glb`);
	const jsonLength = glb.readUInt32LE(12);
	const json = JSON.parse(glb.subarray(20, 20 + jsonLength).toString("utf8").trim());
	const rest = glb.subarray(20 + jsonLength);  // The binary chunk, untouched.
	const scene = json.scenes[json.scene || 0];
	if (json.nodes.some((n) => n.name === "LaidFlat")) {
		console.log(`${file}: already flat`);
		continue;
	}
	json.nodes.push({ name: "LaidFlat", rotation: [-Math.SQRT1_2, 0, 0, Math.SQRT1_2], children: scene.nodes });
	scene.nodes = [json.nodes.length - 1];
	let text = Buffer.from(JSON.stringify(json), "utf8");
	const pad = (4 - (text.length % 4)) % 4;
	text = Buffer.concat([text, Buffer.alloc(pad, 0x20)]);
	const header = Buffer.alloc(20);
	header.writeUInt32LE(0x46546c67, 0);
	header.writeUInt32LE(2, 4);
	header.writeUInt32LE(20 + text.length + rest.length, 8);
	header.writeUInt32LE(text.length, 12);
	header.writeUInt32LE(0x4e4f534a, 16);
	fs.writeFileSync(file, Buffer.concat([header, text, rest]));
	console.log(`${file}: laid flat`);
}
