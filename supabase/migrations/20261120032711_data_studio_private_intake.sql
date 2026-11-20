-- Institutional collection only. No seed authority, canonical writes or hosted activation.
CREATE SCHEMA data_studio;
REVOKE ALL ON SCHEMA data_studio FROM PUBLIC, anon, authenticated, service_role;
CREATE TABLE data_studio.platform_admins (user_id uuid PRIMARY KEY REFERENCES auth.users(id), expires_at timestamptz NOT NULL);
CREATE TABLE data_studio.organizations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL CHECK(length(name) BETWEEN 1 AND 160),
 description text NOT NULL DEFAULT '', synthetic boolean NOT NULL DEFAULT true CHECK(synthetic), created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE data_studio.org_members (
 org_id uuid REFERENCES data_studio.organizations(id), user_id uuid REFERENCES auth.users(id),
 role text NOT NULL CHECK(role IN ('admin','member')), active boolean NOT NULL DEFAULT true,
 PRIMARY KEY(org_id,user_id));
CREATE INDEX studio_org_user ON data_studio.org_members(user_id,org_id);
CREATE TABLE data_studio.language_proposals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL REFERENCES data_studio.organizations(id),
 owner_id uuid NOT NULL REFERENCES auth.users(id), name text NOT NULL CHECK(length(name) BETWEEN 1 AND 160),
 description text NOT NULL, status text NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','COLLECTION_ALLOWED','REJECTED')));
CREATE TABLE data_studio.projects (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL REFERENCES data_studio.organizations(id),
 title text NOT NULL CHECK(length(title) BETWEEN 1 AND 160), language_id uuid REFERENCES public.languages(id),
 variety_id uuid REFERENCES public.dialects(id), proposal_id uuid REFERENCES data_studio.language_proposals(id),
 external_ai boolean NOT NULL DEFAULT false, active boolean NOT NULL DEFAULT true,
 CHECK(num_nonnulls(language_id,variety_id,proposal_id)=1));
CREATE INDEX studio_projects_org ON data_studio.projects(org_id);
CREATE TABLE data_studio.project_members (
 project_id uuid REFERENCES data_studio.projects(id), user_id uuid REFERENCES auth.users(id),
 role text NOT NULL CHECK(role IN ('pi','researcher','contributor')), active boolean NOT NULL DEFAULT true,
 PRIMARY KEY(project_id,user_id));
CREATE INDEX studio_project_user ON data_studio.project_members(user_id,project_id);
CREATE TABLE data_studio.invitations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL REFERENCES data_studio.organizations(id),
 project_id uuid REFERENCES data_studio.projects(id), email text NOT NULL, role text NOT NULL,
 token_hash text NOT NULL UNIQUE, expires_at timestamptz NOT NULL DEFAULT now()+interval '7 days',
 accepted_by uuid REFERENCES auth.users(id), revoked boolean NOT NULL DEFAULT false,
 CHECK((project_id IS NULL AND role IN ('admin','member')) OR (project_id IS NOT NULL AND role IN ('pi','researcher','contributor'))));
CREATE TABLE data_studio.campaigns (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), project_id uuid NOT NULL REFERENCES data_studio.projects(id),
 title text NOT NULL CHECK(length(title) BETWEEN 1 AND 160), category text NOT NULL,
 template jsonb NOT NULL CHECK(jsonb_typeof(template)='array'), target_count integer NOT NULL DEFAULT 10 CHECK(target_count BETWEEN 1 AND 100000));
CREATE TABLE data_studio.contributions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), campaign_id uuid NOT NULL REFERENCES data_studio.campaigns(id),
 owner_id uuid NOT NULL REFERENCES auth.users(id), content jsonb NOT NULL CHECK(jsonb_typeof(content)='object'),
 consent jsonb NOT NULL, consent_version text NOT NULL DEFAULT 'STUDIO-CONSENT-1',
 status text NOT NULL DEFAULT 'DRAFT' CHECK(status IN ('DRAFT','SUBMITTED','TRIAGED','NEEDS_CLARIFICATION','ACCEPTED_FOR_RESEARCH_INTAKE','REJECTED','WITHDRAWN')),
 revision integer NOT NULL DEFAULT 1, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX studio_contribution_campaign ON data_studio.contributions(campaign_id,created_at);
CREATE INDEX studio_contribution_owner ON data_studio.contributions(owner_id);
CREATE TABLE data_studio.uploads (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), contribution_id uuid NOT NULL REFERENCES data_studio.contributions(id),
 object_path text NOT NULL UNIQUE, mime text NOT NULL CHECK(mime IN ('text/plain','application/pdf','audio/wav','audio/webm')),
 size_bytes integer NOT NULL CHECK(size_bytes BETWEEN 1 AND 5242880), sha256 text NOT NULL CHECK(sha256 ~ '^[a-f0-9]{64}$'),
 state text NOT NULL DEFAULT 'QUARANTINED' CHECK(state='QUARANTINED'));
CREATE TABLE data_studio.events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, actor uuid NOT NULL REFERENCES auth.users(id),
 org_id uuid REFERENCES data_studio.organizations(id), project_id uuid REFERENCES data_studio.projects(id),
 contribution_id uuid REFERENCES data_studio.contributions(id), action text NOT NULL, snapshot jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX studio_events_project ON data_studio.events(project_id,created_at);
CREATE TABLE data_studio.requests (
 actor uuid REFERENCES auth.users(id), request_id uuid, body jsonb NOT NULL, result jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(actor,request_id));
CREATE TABLE data_studio.ai_runs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), contribution_id uuid NOT NULL REFERENCES data_studio.contributions(id),
 actor uuid NOT NULL REFERENCES auth.users(id), revision integer NOT NULL, provider text NOT NULL CHECK(provider IN ('mock','openai')),
 workflow text NOT NULL, state text NOT NULL DEFAULT 'RUNNING' CHECK(state IN ('RUNNING','SUCCEEDED','FAILED','CANCELLED')),
 result jsonb, model text, prompt_version text NOT NULL DEFAULT 'STUDIO-ASSIST-1', config_version text NOT NULL DEFAULT '1',
 origin text NOT NULL DEFAULT 'MACHINE_GENERATED' CHECK(origin='MACHINE_GENERATED'),
 verification text NOT NULL DEFAULT 'UNVERIFIED' CHECK(verification='UNVERIFIED'), elapsed_ms integer,
 created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX studio_ai_actor ON data_studio.ai_runs(actor,created_at);
CREATE TABLE data_studio.handoffs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), contribution_id uuid NOT NULL UNIQUE REFERENCES data_studio.contributions(id),
 packet jsonb NOT NULL, state text NOT NULL DEFAULT 'PREPARED_BLOCKED' CHECK(state IN ('PREPARED_BLOCKED','WITHDRAWN')));

-- Private tables have defense-in-depth RLS and no ordinary table privileges.
DO $$ DECLARE t text; BEGIN
 FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='data_studio' LOOP
 EXECUTE format('ALTER TABLE data_studio.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('REVOKE ALL ON data_studio.%I FROM PUBLIC, anon, authenticated, service_role',t);
 END LOOP;
END $$;

CREATE FUNCTION data_studio.org_admin(o uuid, u uuid) RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM data_studio.org_members WHERE org_id=o AND user_id=u AND active AND role='admin') $$;
CREATE FUNCTION data_studio.project_role(p uuid,u uuid) RETURNS text LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT CASE WHEN data_studio.org_admin(x.org_id,u) THEN 'pi' ELSE
 (SELECT m.role FROM data_studio.project_members m WHERE m.project_id=x.id AND m.user_id=u AND m.active) END
 FROM data_studio.projects x WHERE x.id=p AND x.active $$;
CREATE FUNCTION data_studio.can_read(c uuid,u uuid) RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM data_studio.contributions x JOIN data_studio.campaigns k ON k.id=x.campaign_id
 WHERE x.id=c AND data_studio.project_role(k.project_id,u) IS NOT NULL
 AND (x.owner_id=u OR data_studio.project_role(k.project_id,u) IN ('pi','researcher'))) $$;

CREATE FUNCTION public.studio_state() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); result jsonb;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
 SELECT jsonb_build_object('user_id',u,'platform_admin',EXISTS(SELECT 1 FROM data_studio.platform_admins WHERE user_id=u AND expires_at>now()),
 'organizations',COALESCE((SELECT jsonb_agg(to_jsonb(o)||jsonb_build_object('role',m.role)) FROM data_studio.organizations o JOIN data_studio.org_members m ON m.org_id=o.id WHERE m.user_id=u AND m.active),'[]'::jsonb),
 'partners',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',o.id,'name',o.name)) FROM data_studio.organizations o WHERE EXISTS(SELECT 1 FROM data_studio.platform_admins WHERE user_id=u AND expires_at>now())),'[]'::jsonb),
 'projects',COALESCE((SELECT jsonb_agg(to_jsonb(p)||jsonb_build_object('role',data_studio.project_role(p.id,u))) FROM data_studio.projects p WHERE data_studio.project_role(p.id,u) IS NOT NULL),'[]'::jsonb),
 'proposals',COALESCE((SELECT jsonb_agg(to_jsonb(p)) FROM data_studio.language_proposals p WHERE p.owner_id=u OR EXISTS(SELECT 1 FROM data_studio.org_members m WHERE m.org_id=p.org_id AND m.user_id=u AND m.active)),'[]'::jsonb),
 'languages',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',id,'name',name,'kind','language')) FROM public.languages),'[]'::jsonb),
 'varieties',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',id,'name',name,'kind','variety')) FROM public.dialects),'[]'::jsonb),
 'campaigns',COALESCE((SELECT jsonb_agg(to_jsonb(c)) FROM data_studio.campaigns c WHERE data_studio.project_role(c.project_id,u) IS NOT NULL),'[]'::jsonb),
 'contributions',COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.updated_at DESC) FROM data_studio.contributions c WHERE data_studio.can_read(c.id,u)),'[]'::jsonb),
 'uploads',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM data_studio.uploads x WHERE data_studio.can_read(x.contribution_id,u)),'[]'::jsonb),
 'ai_runs',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM data_studio.ai_runs x WHERE data_studio.can_read(x.contribution_id,u)),'[]'::jsonb),
 'handoffs',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM data_studio.handoffs x WHERE data_studio.can_read(x.contribution_id,u)),'[]'::jsonb),
 'invitations',COALESCE((SELECT jsonb_agg(to_jsonb(i)-'token_hash') FROM data_studio.invitations i WHERE data_studio.org_admin(i.org_id,u) OR data_studio.project_role(i.project_id,u)='pi'),'[]'::jsonb),
 'members',COALESCE((SELECT jsonb_agg(to_jsonb(m)||jsonb_build_object('email',a.email)) FROM data_studio.project_members m JOIN auth.users a ON a.id=m.user_id WHERE data_studio.project_role(m.project_id,u)='pi'),'[]'::jsonb),
 'org_members',COALESCE((SELECT jsonb_agg(to_jsonb(m)||jsonb_build_object('email',a.email)) FROM data_studio.org_members m JOIN auth.users a ON a.id=m.user_id WHERE data_studio.org_admin(m.org_id,u)),'[]'::jsonb),
 'events',COALESCE((SELECT jsonb_agg(to_jsonb(e)) FROM (SELECT * FROM data_studio.events e WHERE
 (e.contribution_id IS NOT NULL AND data_studio.can_read(e.contribution_id,u)) OR
 (e.contribution_id IS NULL AND (data_studio.org_admin(e.org_id,u) OR data_studio.project_role(e.project_id,u)='pi')) ORDER BY id DESC LIMIT 200) e),'[]'::jsonb)) INTO result;
 RETURN result;
END $$;

CREATE FUNCTION public.studio_command(operation text, payload jsonb, request_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
#variable_conflict use_variable
DECLARE u uuid:=auth.uid(); body jsonb:=jsonb_build_object('op',operation,'payload',
 CASE WHEN payload ? 'token' THEN (payload-'token')||jsonb_build_object('token_sha256',encode(sha256(convert_to(payload->>'token','UTF8')),'hex')) ELSE payload END); previous data_studio.requests;
 o uuid; p uuid; id uuid; c data_studio.contributions; k data_studio.campaigns; inv data_studio.invitations;
 pr data_studio.projects; token text; result jsonb; content jsonb; consent jsonb; field jsonb; role_name text; next_state text; ai data_studio.ai_runs;
BEGIN
 IF u IS NULL OR request_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR length(payload::text)>60000 THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
 -- Serializes retries and membership changes in this bounded synthetic MVP.
 PERFORM pg_advisory_xact_lock(7414001);
 SELECT * INTO previous FROM data_studio.requests r WHERE r.actor=u AND r.request_id=studio_command.request_id;
 IF FOUND THEN
   IF previous.body<>body THEN RAISE EXCEPTION 'STUDIO_CONFLICT'; END IF;
   -- Do not replay private results after membership revocation: only a receipt is returned.
   RETURN jsonb_build_object('replayed',true,'id',previous.result->'id');
 END IF;
 IF (SELECT count(*) FROM data_studio.requests WHERE actor=u AND created_at>now()-interval '1 day')>=1000 THEN RAISE EXCEPTION 'STUDIO_LIMIT'; END IF;
 o:=NULLIF(payload->>'org_id','')::uuid; p:=NULLIF(payload->>'project_id','')::uuid; id:=NULLIF(payload->>'id','')::uuid;
 IF operation='onboard' THEN
   IF NOT EXISTS(SELECT 1 FROM data_studio.platform_admins WHERE user_id=u AND expires_at>now()) THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
   INSERT INTO data_studio.organizations(name) VALUES(payload->>'name') RETURNING organizations.id INTO o;
   token:=gen_random_uuid()::text||gen_random_uuid()::text;
   INSERT INTO data_studio.invitations(org_id,email,role,token_hash) VALUES(o,lower(payload->>'email'),'admin',encode(sha256(convert_to(token,'UTF8')),'hex')) RETURNING invitations.id INTO id;
   result:=jsonb_build_object('id',id,'token',token,'org_id',o);
 ELSIF operation='accept_invitation' THEN
   SELECT * INTO inv FROM data_studio.invitations WHERE token_hash=encode(sha256(convert_to(payload->>'token','UTF8')),'hex') FOR UPDATE;
   IF NOT FOUND OR inv.revoked OR inv.expires_at<=now() OR inv.accepted_by IS NOT NULL OR NOT EXISTS(
     SELECT 1 FROM auth.users WHERE users.id=u AND lower(email)=inv.email AND email_confirmed_at IS NOT NULL) THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
   o:=inv.org_id; p:=inv.project_id; id:=inv.id;
   IF p IS NULL THEN INSERT INTO data_studio.org_members VALUES(o,u,inv.role,true) ON CONFLICT(org_id,user_id) DO UPDATE SET role=EXCLUDED.role,active=true;
   ELSE INSERT INTO data_studio.project_members VALUES(p,u,inv.role,true) ON CONFLICT(project_id,user_id) DO UPDATE SET role=EXCLUDED.role,active=true; END IF;
   UPDATE data_studio.invitations SET accepted_by=u WHERE invitations.id=id;
   result:=jsonb_build_object('id',id);
 ELSIF operation IN ('invite','revoke_invitation','revoke_member') THEN
   IF p IS NOT NULL THEN SELECT org_id INTO o FROM data_studio.projects WHERE projects.id=p; END IF;
   IF NOT COALESCE(data_studio.org_admin(o,u),false) AND data_studio.project_role(p,u) IS DISTINCT FROM 'pi' THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
   IF operation='invite' THEN
     role_name:=payload->>'role'; token:=gen_random_uuid()::text||gen_random_uuid()::text;
     INSERT INTO data_studio.invitations(org_id,project_id,email,role,token_hash) VALUES(o,p,lower(payload->>'email'),role_name,encode(sha256(convert_to(token,'UTF8')),'hex')) RETURNING invitations.id INTO id;
     result:=jsonb_build_object('id',id,'token',token);
   ELSIF operation='revoke_invitation' THEN
     UPDATE data_studio.invitations SET revoked=true WHERE invitations.id=id AND org_id=o AND project_id IS NOT DISTINCT FROM p;
     IF NOT FOUND THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
     result:=jsonb_build_object('id',id);
   ELSE
     IF id=u THEN RAISE EXCEPTION 'STUDIO_SELF_REVOCATION'; END IF;
     IF p IS NULL THEN UPDATE data_studio.org_members SET active=false WHERE org_id=o AND user_id=id;
     ELSE UPDATE data_studio.project_members SET active=false WHERE project_id=p AND user_id=id; END IF;
     result:=jsonb_build_object('id',id);
   END IF;
 ELSIF operation IN ('update_org','propose_language','process_language','create_project') THEN
   IF operation='propose_language' THEN
     IF NOT EXISTS(SELECT 1 FROM data_studio.org_members WHERE org_id=o AND user_id=u AND active)
       AND NOT EXISTS(SELECT 1 FROM data_studio.projects x WHERE x.org_id=o AND data_studio.project_role(x.id,u) IS NOT NULL)
       THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
   ELSIF NOT data_studio.org_admin(o,u) THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
   IF operation='update_org' THEN
     UPDATE data_studio.organizations SET name=payload->>'name',description=left(COALESCE(payload->>'description',''),2000) WHERE organizations.id=o;
     result:=jsonb_build_object('id',o);
   ELSIF operation='propose_language' THEN
     INSERT INTO data_studio.language_proposals(org_id,owner_id,name,description) VALUES(o,u,payload->>'name',COALESCE(payload->>'description','')) RETURNING language_proposals.id INTO id;
     result:=jsonb_build_object('id',id);
   ELSIF operation='process_language' THEN
     IF payload->>'status' NOT IN ('COLLECTION_ALLOWED','REJECTED') THEN RAISE EXCEPTION 'STUDIO_INVALID'; END IF;
     UPDATE data_studio.language_proposals SET status=payload->>'status' WHERE language_proposals.id=id AND org_id=o AND status='PENDING';
     IF NOT FOUND THEN RAISE EXCEPTION 'STUDIO_CONFLICT'; END IF;
     result:=jsonb_build_object('id',id);
   ELSE
     IF payload->>'proposal_id' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM data_studio.language_proposals WHERE language_proposals.id=(payload->>'proposal_id')::uuid AND org_id=o AND status='COLLECTION_ALLOWED') THEN RAISE EXCEPTION 'STUDIO_SCOPE'; END IF;
     INSERT INTO data_studio.projects(org_id,title,language_id,variety_id,proposal_id) VALUES(o,payload->>'title',NULLIF(payload->>'language_id','')::uuid,NULLIF(payload->>'variety_id','')::uuid,NULLIF(payload->>'proposal_id','')::uuid) RETURNING projects.id INTO p;
     result:=jsonb_build_object('id',p);
   END IF;
 ELSIF operation IN ('create_campaign','project_settings') THEN
   IF data_studio.project_role(p,u) IS DISTINCT FROM 'pi' THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
   SELECT org_id INTO o FROM data_studio.projects WHERE projects.id=p;
   IF operation='project_settings' THEN
     UPDATE data_studio.projects SET external_ai=(payload->>'external_ai')::boolean WHERE projects.id=p;
     result:=jsonb_build_object('id',p);
   ELSE
     IF payload->>'category' NOT IN ('WORD','SENTENCE_PAIR','PROVERB_IDIOM','NARRATIVE','PRONUNCIATION','CONVERSATION','DOCUMENT','ANNOTATION','CULTURAL_CONTEXT') OR jsonb_typeof(payload->'template')<>'array' OR jsonb_array_length(payload->'template')>12 THEN RAISE EXCEPTION 'STUDIO_INVALID'; END IF;
     FOR field IN SELECT value FROM jsonb_array_elements(payload->'template') LOOP
       IF COALESCE(field->>'key','') !~ '^[a-z][a-z0-9_]{0,39}$' OR length(COALESCE(field->>'label','')) NOT BETWEEN 1 AND 100 OR jsonb_typeof(field->'required') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'STUDIO_TEMPLATE'; END IF;
     END LOOP;
     IF (SELECT count(*)<>count(DISTINCT value->>'key') FROM jsonb_array_elements(payload->'template')) THEN RAISE EXCEPTION 'STUDIO_TEMPLATE'; END IF;
     INSERT INTO data_studio.campaigns(project_id,title,category,template,target_count) VALUES(p,payload->>'title',payload->>'category',payload->'template',COALESCE((payload->>'target_count')::integer,10)) RETURNING campaigns.id INTO id;
     result:=jsonb_build_object('id',id);
   END IF;
 ELSIF operation='save' THEN
   SELECT * INTO k FROM data_studio.campaigns WHERE campaigns.id=(payload->>'campaign_id')::uuid;
   p:=k.project_id;
   IF p IS NULL OR data_studio.project_role(p,u) IS NULL THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
   SELECT org_id INTO o FROM data_studio.projects WHERE projects.id=p;
   content:=payload->'content'; consent:=payload->'consent';
   IF jsonb_typeof(content) IS DISTINCT FROM 'object' OR length(content::text)>30000 OR jsonb_typeof(consent) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'STUDIO_INVALID'; END IF;
   IF EXISTS(SELECT 1 FROM jsonb_each(content) WHERE jsonb_typeof(value)<>'string' OR length(value#>>'{}')>20000) THEN RAISE EXCEPTION 'STUDIO_INVALID'; END IF;
   IF NOT consent ?& ARRAY['internal_research','human_review','training','public_display','redistribution','commercial','external_ai'] OR EXISTS(SELECT 1 FROM jsonb_each(consent) WHERE jsonb_typeof(value)<>'boolean') THEN RAISE EXCEPTION 'STUDIO_CONSENT'; END IF;
   IF id IS NULL THEN
     INSERT INTO data_studio.contributions(campaign_id,owner_id,content,consent) VALUES(k.id,u,content,consent) RETURNING * INTO c; id:=c.id;
   ELSE
     SELECT * INTO c FROM data_studio.contributions WHERE contributions.id=id FOR UPDATE;
     IF NOT FOUND OR c.owner_id<>u OR c.campaign_id<>k.id THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
     IF c.status NOT IN ('DRAFT','NEEDS_CLARIFICATION') OR c.revision IS DISTINCT FROM (payload->>'revision')::integer THEN RAISE EXCEPTION 'STUDIO_CONFLICT'; END IF;
     UPDATE data_studio.contributions SET content=payload->'content',consent=payload->'consent',revision=revision+1,updated_at=now() WHERE contributions.id=id RETURNING * INTO c;
   END IF;
   result:=to_jsonb(c);
 ELSE
   SELECT * INTO c FROM data_studio.contributions WHERE contributions.id=id FOR UPDATE;
   IF NOT FOUND OR NOT data_studio.can_read(id,u) THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
   SELECT * INTO k FROM data_studio.campaigns WHERE campaigns.id=c.campaign_id;
   p:=k.project_id; SELECT * INTO pr FROM data_studio.projects WHERE projects.id=p; o:=pr.org_id;
   IF operation IN ('submit','withdraw','transition') AND c.revision IS DISTINCT FROM (payload->>'revision')::integer THEN RAISE EXCEPTION 'STUDIO_CONFLICT'; END IF;
   IF operation='submit' THEN
     IF c.owner_id<>u OR c.status NOT IN ('DRAFT','NEEDS_CLARIFICATION') THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
     IF NOT (c.consent->>'internal_research')::boolean OR NOT (c.consent->>'human_review')::boolean THEN RAISE EXCEPTION 'STUDIO_CONSENT'; END IF;
     IF length(COALESCE(c.content->>'text',''))=0 OR length(COALESCE(c.content->>'source',''))=0 OR length(COALESCE(c.content->>'method',''))=0 THEN RAISE EXCEPTION 'STUDIO_REQUIRED'; END IF;
     FOR field IN SELECT value FROM jsonb_array_elements(k.template) LOOP
       IF (field->>'required')::boolean AND length(trim(COALESCE(c.content->>(field->>'key'),'')))=0 THEN RAISE EXCEPTION 'STUDIO_REQUIRED'; END IF;
     END LOOP;
     IF k.category='SENTENCE_PAIR' AND (length(COALESCE(c.content->>'translation',''))=0 OR length(COALESCE(c.content->>'counterpart_scope',''))=0) THEN RAISE EXCEPTION 'STUDIO_SCOPE'; END IF;
     next_state:='SUBMITTED';
   ELSIF operation='transition' THEN
     IF data_studio.project_role(p,u) NOT IN ('pi','researcher') THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
     next_state:=payload->>'status';
     IF length(trim(COALESCE(payload->>'reason','')))=0 OR NOT (
       (c.status='SUBMITTED' AND next_state IN ('TRIAGED','NEEDS_CLARIFICATION','REJECTED')) OR
       (c.status='TRIAGED' AND next_state IN ('ACCEPTED_FOR_RESEARCH_INTAKE','NEEDS_CLARIFICATION','REJECTED'))) THEN RAISE EXCEPTION 'STUDIO_TRANSITION'; END IF;
   ELSIF operation='withdraw' THEN
     IF c.owner_id<>u OR c.status='WITHDRAWN' THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
     next_state:='WITHDRAWN';
     UPDATE data_studio.handoffs SET state='WITHDRAWN' WHERE contribution_id=id;
     UPDATE data_studio.ai_runs SET state='CANCELLED',result=NULL WHERE contribution_id=id AND state='RUNNING';
   ELSIF operation='correction' THEN
     IF c.owner_id<>u OR c.status NOT IN ('SUBMITTED','TRIAGED','ACCEPTED_FOR_RESEARCH_INTAKE') OR length(trim(COALESCE(payload->>'reason','')))=0 THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
     result:=jsonb_build_object('id',id,'status','CORRECTION_REQUESTED');
   ELSIF operation='upload_intent' THEN
     IF c.owner_id<>u OR c.status NOT IN ('DRAFT','NEEDS_CLARIFICATION') OR (SELECT count(*) FROM data_studio.uploads WHERE contribution_id=id)>=10 THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
     token:=u::text||'/'||gen_random_uuid()::text;
     INSERT INTO data_studio.uploads(contribution_id,object_path,mime,size_bytes,sha256) VALUES(id,token,payload->>'mime',(payload->>'size_bytes')::integer,payload->>'sha256') RETURNING to_jsonb(uploads.*) INTO result;
   ELSIF operation='prepare_handoff' THEN
     IF data_studio.project_role(p,u) NOT IN ('pi','researcher') OR c.status<>'ACCEPTED_FOR_RESEARCH_INTAKE' OR NOT (c.consent->>'internal_research')::boolean OR NOT (c.consent->>'human_review')::boolean THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
     result:=jsonb_build_object('origin',to_jsonb(c),'scope',jsonb_build_object('language_id',pr.language_id,'variety_id',pr.variety_id,'proposal_id',pr.proposal_id),
       'uploads',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM data_studio.uploads x WHERE contribution_id=id),'[]'::jsonb),
       'human_verified',false,'canonical_approved',false,'training_approved',false,'commercially_cleared',false,'reviewer_handoff','BLOCKED_PENDING_AUTHORIZED_INTEGRATION');
     INSERT INTO data_studio.handoffs(contribution_id,packet) VALUES(id,result) ON CONFLICT(contribution_id) DO NOTHING;
     SELECT to_jsonb(h.*) INTO result FROM data_studio.handoffs h WHERE contribution_id=id;
   ELSIF operation='assist_begin' THEN
     IF c.status IN ('WITHDRAWN','REJECTED') OR payload->>'provider' NOT IN ('mock','openai') OR payload->>'workflow' NOT IN ('document','vocabulary','quality','clarification','completeness','audio') THEN RAISE EXCEPTION 'STUDIO_PROVIDER'; END IF;
     IF payload->>'provider'='openai' AND (NOT pr.external_ai OR NOT (c.consent->>'external_ai')::boolean) THEN RAISE EXCEPTION 'STUDIO_CONSENT'; END IF;
     IF (SELECT count(*) FROM data_studio.ai_runs WHERE actor=u AND created_at>now()-interval '1 day')>=20 OR
        (SELECT count(*) FROM data_studio.ai_runs a JOIN data_studio.contributions x ON x.id=a.contribution_id JOIN data_studio.campaigns y ON y.id=x.campaign_id WHERE y.project_id=p AND a.created_at>now()-interval '1 day')>=100 THEN RAISE EXCEPTION 'STUDIO_LIMIT'; END IF;
     INSERT INTO data_studio.ai_runs(contribution_id,actor,revision,provider,workflow) VALUES(id,u,c.revision,payload->>'provider',payload->>'workflow') RETURNING * INTO ai;
     result:=to_jsonb(ai)||jsonb_build_object('content',c.content,'scope',jsonb_build_object('language_id',pr.language_id,'variety_id',pr.variety_id,'proposal_id',pr.proposal_id),
       'duplicate_count',(SELECT count(*) FROM data_studio.contributions x JOIN data_studio.campaigns y ON y.id=x.campaign_id WHERE y.project_id=p AND x.id<>id AND x.content->>'text'=c.content->>'text' AND data_studio.can_read(x.id,u)));
   ELSE RAISE EXCEPTION 'STUDIO_OPERATION'; END IF;
   IF next_state IS NOT NULL THEN
     UPDATE data_studio.contributions SET status=next_state,revision=revision+1,updated_at=now() WHERE contributions.id=id RETURNING * INTO c;
     result:=to_jsonb(c);
   END IF;
 END IF;
 INSERT INTO data_studio.events(actor,org_id,project_id,contribution_id,action,snapshot)
 VALUES(u,o,p,c.id,operation,jsonb_build_object('payload',payload-'token','contribution',to_jsonb(c),'result',result-'token'-'content'));
 INSERT INTO data_studio.requests VALUES(u,request_id,body,result-'token',now());
 RETURN result;
END $$;

CREATE FUNCTION public.studio_ai_finish(run_id uuid, output jsonb, model_name text, duration_ms integer, failed boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a data_studio.ai_runs; c data_studio.contributions; p data_studio.projects;
BEGIN
 PERFORM pg_advisory_xact_lock(7414001);
 SELECT * INTO a FROM data_studio.ai_runs WHERE id=run_id FOR UPDATE;
 IF NOT FOUND OR a.state<>'RUNNING' THEN RAISE EXCEPTION 'STUDIO_CONFLICT'; END IF;
 SELECT * INTO c FROM data_studio.contributions WHERE id=a.contribution_id;
 SELECT x.* INTO p FROM data_studio.projects x JOIN data_studio.campaigns k ON k.project_id=x.id WHERE k.id=c.campaign_id;
 IF NOT data_studio.can_read(c.id,a.actor) OR c.status IN ('WITHDRAWN','REJECTED') OR c.revision<>a.revision OR
    (a.provider='openai' AND (NOT p.external_ai OR NOT (c.consent->>'external_ai')::boolean)) THEN
   UPDATE data_studio.ai_runs SET state='CANCELLED' WHERE id=run_id; RETURN jsonb_build_object('state','CANCELLED');
 END IF;
 IF length(output::text)>30000 OR duration_ms NOT BETWEEN 0 AND 120000 THEN RAISE EXCEPTION 'STUDIO_INVALID'; END IF;
 UPDATE data_studio.ai_runs SET result=output,model=model_name,elapsed_ms=duration_ms,state=CASE WHEN failed THEN 'FAILED' ELSE 'SUCCEEDED' END WHERE id=run_id;
 RETURN jsonb_build_object('id',run_id,'state',CASE WHEN failed THEN 'FAILED' ELSE 'SUCCEEDED' END);
END $$;

CREATE FUNCTION public.studio_object_access(object_name text, writing boolean DEFAULT false) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM data_studio.uploads x JOIN data_studio.contributions c ON c.id=x.contribution_id
 WHERE x.object_path=object_name AND data_studio.can_read(c.id,auth.uid()) AND c.status<>'WITHDRAWN'
 AND (NOT writing OR (c.owner_id=auth.uid() AND c.status IN ('DRAFT','NEEDS_CLARIFICATION')))) $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA data_studio FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.studio_state(),public.studio_command(text,jsonb,uuid),public.studio_object_access(text,boolean),public.studio_ai_finish(uuid,jsonb,text,integer,boolean) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.studio_state(),public.studio_command(text,jsonb,uuid),public.studio_object_access(text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.studio_ai_finish(uuid,jsonb,text,integer,boolean) TO service_role;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('studio-quarantine','studio-quarantine',false,5242880,ARRAY['text/plain','application/pdf','audio/wav','audio/webm']);
CREATE POLICY studio_upload_insert ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(bucket_id='studio-quarantine' AND public.studio_object_access(name,true));
CREATE POLICY studio_upload_read ON storage.objects FOR SELECT TO authenticated
 USING(bucket_id='studio-quarantine' AND public.studio_object_access(name,false));
