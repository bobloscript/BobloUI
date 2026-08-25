import { readdirSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const files = [];

function walk(directory) {
	for (const entry of readdirSync(join(root, directory), { withFileTypes: true })) {
		const relative = join(directory, entry.name);
		if (entry.isDirectory()) {
			walk(relative);
		} else if (entry.name.endsWith(".lua")) {
			files.push(relative);
		}
	}
}

for (const directory of ["src", "tests", "examples"]) {
	walk(directory);
}

const args = ["--no-ignore-vcs"];
if (process.argv.includes("--check")) {
	args.push("--check");
}
args.push(...files);

const result = spawnSync(process.platform === "win32" ? "stylua.exe" : "stylua", args, {
	cwd: root,
	stdio: "inherit",
});

if (result.error) {
	console.error(`failed to run StyLua: ${result.error.message}`);
	process.exit(1);
}
process.exit(result.status ?? 1);
