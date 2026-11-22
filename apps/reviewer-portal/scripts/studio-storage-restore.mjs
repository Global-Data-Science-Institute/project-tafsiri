// Local synthetic Storage recovery rehearsal. Never changes source objects.
import { createClient } from "@supabase/supabase-js";
import { execFileSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { mkdir, writeFile, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../..",
);
const result = execFileSync(
  process.platform === "win32"
    ? "cmd.exe"
    : path.join(root, "node_modules/.bin/supabase"),
  process.platform === "win32"
    ? [
        "/c",
        "node_modules\\.bin\\supabase.cmd status --workdir .studio-local --output json",
      ]
    : ["status", "--workdir", ".studio-local", "--output", "json"],
  { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] },
);
const s = JSON.parse(result);
if (s.API_URL !== "http://127.0.0.1:55621")
  throw new Error("Isolated local stack required");
const options = { auth: { persistSession: false, autoRefreshToken: false } };
const client = createClient(
  s.API_URL,
  s.SECRET_KEY ?? s.SERVICE_ROLE_KEY,
  options,
);
const anon = createClient(s.API_URL, s.PUBLISHABLE_KEY ?? s.ANON_KEY, options);
const paths = JSON.parse(
  execFileSync(
    "docker",
    [
      "exec",
      "supabase_db_tafsiri-studio-synthetic",
      "psql",
      "-XqAt",
      "-U",
      "postgres",
      "-d",
      "postgres",
      "-c",
      "SELECT COALESCE(json_agg(name),'[]') FROM storage.objects WHERE bucket_id='studio-quarantine'",
    ],
    { encoding: "utf8" },
  ),
);
if (!paths.length)
  throw new Error(
    "Run Studio acceptance first: no synthetic objects to recover",
  );
const destination = `studio-restore-${randomUUID()}`;
const directory = path.join(
  root,
  ".studio-local",
  "storage-backup",
  destination,
);
await mkdir(directory, { recursive: true });
const created = await client.storage.createBucket(destination, {
  public: false,
});
if (created.error) throw created.error;
const restored = [],
  manifest = [];
const digest = (bytes) => createHash("sha256").update(bytes).digest("hex");
try {
  for (const [index, source] of paths.entries()) {
    const original = await client.storage
      .from("studio-quarantine")
      .download(source);
    if (original.error) throw original.error;
    const bytes = Buffer.from(await original.data.arrayBuffer()),
      name = `${index}.bin`;
    await writeFile(path.join(directory, name), bytes);
    manifest.push({
      source,
      archive: name,
      sha256: digest(bytes),
      size: bytes.length,
    });
    const uploaded = await client.storage
      .from(destination)
      .upload(name, await readFile(path.join(directory, name)));
    if (uploaded.error) throw uploaded.error;
    restored.push(name);
    const recovered = await client.storage.from(destination).download(name);
    if (
      recovered.error ||
      digest(Buffer.from(await recovered.data.arrayBuffer())) !== digest(bytes)
    )
      throw new Error("Storage checksum mismatch");
    const forbidden = await anon.storage.from(destination).download(name);
    if (!forbidden.error) throw new Error("Restored private object exposed");
  }
  await writeFile(
    path.join(directory, "manifest.json"),
    JSON.stringify(manifest, null, 2),
  );
  console.log(
    `PASS synthetic Storage backup/restore: ${restored.length} objects, checksum equality and anonymous denial`,
  );
} finally {
  if (!destination.startsWith("studio-restore-"))
    throw new Error("Unexpected recovery target");
  if (restored.length) {
    const removed = await client.storage.from(destination).remove(restored);
    if (removed.error) throw removed.error;
  }
  const removed = await client.storage.deleteBucket(destination);
  if (removed.error) throw removed.error;
}
