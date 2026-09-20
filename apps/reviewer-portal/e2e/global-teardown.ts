import { execSync } from "node:child_process";
import path from "node:path";
export default function teardown(){execSync("npx.cmd supabase db reset",{cwd:path.resolve(__dirname,"../../.."),stdio:"inherit"})}
