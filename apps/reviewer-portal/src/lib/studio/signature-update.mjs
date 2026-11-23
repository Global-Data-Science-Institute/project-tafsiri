import { mkdir, mkdtemp, writeFile, chmod, rename, symlink, unlink, readdir } from "node:fs/promises";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { verifySignatures } from "./signatures.mjs";

// Run as the separate updater identity. Scanner identity has read-only access.
// Failed staging directories are left for operator inspection, never activated.
export async function activateSignatures(root, config, runner, prepare) {
  if (!path.isAbsolute(root) || process.platform === "win32") throw new Error("POSIX absolute generation root required");
  await mkdir(root, { recursive: true, mode: 0o755 });
  const lock = path.join(root, ".update-lock");
  await mkdir(lock); // One publisher; interruption requires operator lock recovery.
  const link = path.join(root, `.current-${randomUUID()}`);
  try {
    const stage = await mkdtemp(path.join(root, "generation-"));
    if (prepare) await prepare(stage);
    else {
      if (!path.isAbsolute(config.freshclam ?? "")) throw new Error("Freshclam path required");
      const conf = path.join(lock, "freshclam.conf");
      // Full signed CVD only: CLD differential databases require another review.
      await writeFile(conf, `DatabaseDirectory ${stage}\nDatabaseMirror database.clamav.net\nScriptedUpdates no\nTestDatabases yes\nBytecode yes\n`, { mode: 0o600 });
      await runner(config.freshclam, [`--config-file=${conf}`, "--stdout"], { timeout: 600000, maxBuffer: 65536 });
    }
    const result = await verifySignatures({ ...config, database: stage }, runner);
    for (const name of await readdir(stage)) await chmod(path.join(stage, name), 0o444);
    await chmod(stage, 0o555);
    await symlink(stage, link, "dir");
    await rename(link, path.join(root, "current")); // Atomic switch, previous generations retained for in-flight readers.
    return { ...result, updateStatus: "ACTIVATED" };
  } finally {
    await unlink(link).catch(() => {});
    // Only remove files created in our lock; never recursively delete generations.
    await unlink(path.join(lock, "freshclam.conf")).catch(() => {});
    const { rmdir } = await import("node:fs/promises");
    await rmdir(lock);
  }
}
