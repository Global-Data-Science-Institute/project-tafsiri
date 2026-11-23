import { createRequire } from "node:module";
import { execSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import assert from "node:assert/strict";
const require = createRequire(new URL("../../apps/reviewer-portal/package.json", import.meta.url));
const { createClient } = require("@supabase/supabase-js");
const cli = process.platform === "win32" ? ".\\node_modules\\.bin\\supabase.cmd" : "./node_modules/.bin/supabase";
const status = JSON.parse(execSync(`${cli} status --workdir .studio-local --output json`, {encoding:"utf8",stdio:["ignore","pipe","pipe"]}));
assert.equal(status.API_URL,"http://127.0.0.1:55621");
const opts={auth:{persistSession:false,autoRefreshToken:false}};
const admin=createClient(status.API_URL,status.SECRET_KEY??status.SERVICE_ROLE_KEY,opts);
const make=()=>createClient(status.API_URL,status.PUBLISHABLE_KEY??status.ANON_KEY,opts);
const anon=make(), ids=[], clients=[];
try {
  for(let i=0;i<2;i++) {
    const email=`legacy-${randomUUID()}@synthetic.example`,password=`Synthetic-${randomUUID()}!`;
    const u=await admin.auth.admin.createUser({email,password,email_confirm:true}); assert.equal(u.error,null);ids.push(u.data.user.id);
    const c=make();assert.equal((await c.auth.signInWithPassword({email,password})).error,null);clients.push(c);
  }
  const privateTables=['bible_books','bible_english_verses','bible_luhya_verses','knowledge_base_entries','luhya_dict','luhya_dictionary','luhya_kb','luhya_proverbs','proverb_contributors','proverbs','submission_rate_limits','suspicious_activity','translations','submissions','contributors'];
  const publicTables=['dialect_aliases','pronouns','pronoun_examples'];
  for(const c of [anon,...clients]) {
    for(const t of privateTables) assert.ok((await c.from(t).select('*').limit(1)).error, `${t} SELECT denied`);
    for(const t of [...privateTables,...publicTables]) {
      assert.ok((await c.from(t).insert({})).error,`${t} INSERT denied`);
      const key=t==='proverb_contributors'?'code':'id';
      assert.ok((await c.from(t).update({[key]:key==='code'?'synthetic':randomUUID()}).not(key,'is',null)).error,`${t} UPDATE denied`);
      assert.ok((await c.from(t).delete().not(key,'is',null)).error,`${t} DELETE denied`);
    }
    for(const t of [...publicTables,'languages','dialects','word_details','cultural_terms','language_words','pronoun_comparison','pronoun_details','dialect_comparisons']) assert.equal((await c.from(t).select('*').limit(1)).error,null,`${t} public read`);
    assert.ok((await c.rpc('studio_scan_claim')).error);
    assert.ok((await c.rpc('studio_deletion_claim')).error);
  }
  const inserted=await clients[0].from('user_contributions').insert({user_id:ids[0],contribution_type:'SYNTHETIC',content:{text:'SYNTHETIC untrusted'}}).select('id');
  assert.equal(inserted.error,null);assert.equal(inserted.data.length,1);
  assert.equal((await clients[1].from('user_contributions').select('*').eq('id',inserted.data[0].id)).data.length,0);
  assert.ok((await clients[1].from('user_contributions').insert({user_id:ids[0],content:{}})).error);
  assert.ok((await clients[0].from('user_contributions').insert({user_id:ids[0],status:'approved',content:{}})).error);
  assert.ok((await clients[0].from('user_contributions').update({status:'approved'}).eq('id',inserted.data[0].id)).error);
  assert.equal((await admin.from('lexemes').select('id',{count:'exact',head:true})).count,0);
  assert.equal((await admin.from('source_entries').select('id',{count:'exact',head:true})).count,0);
  await admin.from('user_contributions').delete().in('user_id',ids);
  console.log('PASS direct PostgREST: anonymous + two authenticated identities; CRUD denials, allowed reads, protected RPCs, own intake/cross-user denial, no trusted ingestion');
} finally {
  for(const c of clients) await c.auth.signOut();
  for(const id of ids) await admin.auth.admin.deleteUser(id);
}
