-- Partner RC 001. Additive private controls; no hosted activation or authority seed.
ALTER TABLE data_studio.uploads
 ADD COLUMN scan_state text NOT NULL DEFAULT 'PENDING' CHECK(scan_state IN ('PENDING','CLEAN','MOCK_CLEAN','INFECTED','ERROR','DELETED')),
 ADD COLUMN scan_provider text, ADD COLUMN scan_version text, ADD COLUMN scanned_at timestamptz,
 ADD COLUMN scan_lease uuid, ADD COLUMN lease_until timestamptz;
CREATE INDEX studio_scan_queue ON data_studio.uploads(scan_state,lease_until);
CREATE TABLE data_studio.file_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, upload_id uuid REFERENCES data_studio.uploads(id),
 action text NOT NULL, provider text, scanner_version text, sha256 text NOT NULL, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE data_studio.deletion_requests (
 contribution_id uuid PRIMARY KEY REFERENCES data_studio.contributions(id), requested_by uuid NOT NULL REFERENCES auth.users(id),
 requested_at timestamptz NOT NULL DEFAULT now(), eligible_at timestamptz NOT NULL DEFAULT now()+interval '7 days',
 state text NOT NULL DEFAULT 'PENDING' CHECK(state IN ('PENDING','APPROVED','PURGING','PURGED')),
 approved_by uuid REFERENCES auth.users(id), approved_at timestamptz, purged_at timestamptz, hold boolean NOT NULL DEFAULT false,
 lease uuid, lease_until timestamptz, policy_version text NOT NULL DEFAULT 'SYNTHETIC-RETENTION-1');
CREATE TABLE data_studio.invitation_deliveries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), invitation_id uuid NOT NULL REFERENCES data_studio.invitations(id),
 actor uuid NOT NULL REFERENCES auth.users(id), request_id uuid NOT NULL, provider text NOT NULL CHECK(provider IN ('mock','resend')),
 state text NOT NULL DEFAULT 'PREPARED' CHECK(state IN ('PREPARED','SENT','MOCK_SENT','FAILED','CANCELLED')),
 token_hash text NOT NULL, provider_message_id text, created_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz,
 UNIQUE(actor,request_id));
CREATE INDEX studio_delivery_invitation ON data_studio.invitation_deliveries(invitation_id,created_at);
ALTER TABLE data_studio.file_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_studio.deletion_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_studio.invitation_deliveries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON data_studio.file_events,data_studio.deletion_requests,data_studio.invitation_deliveries FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION data_studio.session_active() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM auth.sessions s JOIN auth.users u ON u.id=s.user_id
 WHERE s.id::text=auth.jwt()->>'session_id' AND s.user_id=auth.uid()
 AND (s.not_after IS NULL OR s.not_after>now()) AND u.email_confirmed_at IS NOT NULL
 AND (u.banned_until IS NULL OR u.banned_until<now())) $$;
REVOKE ALL ON FUNCTION data_studio.session_active() FROM PUBLIC,anon,authenticated,service_role;

-- Preserve the original implementation privately; only guarded public entrypoints remain callable.
ALTER FUNCTION public.studio_command(text,jsonb,uuid) SET SCHEMA data_studio;
ALTER FUNCTION public.studio_state() SET SCHEMA data_studio;
REVOKE ALL ON FUNCTION data_studio.studio_command(text,jsonb,uuid),data_studio.studio_state() FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.studio_command(operation text,payload jsonb,request_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); c data_studio.contributions; p uuid; o uuid; answer jsonb;
BEGIN
 IF NOT data_studio.session_active() THEN RAISE EXCEPTION 'STUDIO_AUTH'; END IF;
 IF request_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR length(payload::text)>60000 THEN RAISE EXCEPTION 'STUDIO_INVALID'; END IF;
 PERFORM pg_advisory_xact_lock(7414001);
 IF operation='upload_receipt' THEN
   IF NOT EXISTS(SELECT 1 FROM data_studio.uploads x JOIN data_studio.contributions item ON item.id=x.contribution_id
     WHERE x.id=(payload->>'id')::uuid AND item.owner_id=u AND item.status IN ('DRAFT','NEEDS_CLARIFICATION') AND data_studio.can_read(item.id,u)) THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
   RETURN jsonb_build_object('present',EXISTS(SELECT 1 FROM storage.objects s JOIN data_studio.uploads x ON x.object_path=s.name
     WHERE s.bucket_id='studio-quarantine' AND x.id=(payload->>'id')::uuid));
 END IF;
 IF operation IN ('request_deletion','retention_hold','approve_deletion') THEN
   SELECT * INTO c FROM data_studio.contributions WHERE id=(payload->>'id')::uuid;
   IF NOT FOUND OR NOT data_studio.can_read(c.id,u) THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
   SELECT k.project_id,x.org_id INTO p,o FROM data_studio.campaigns k JOIN data_studio.projects x ON x.id=k.project_id WHERE k.id=c.campaign_id;
   IF c.status<>'WITHDRAWN' THEN RAISE EXCEPTION 'STUDIO_WITHDRAW_FIRST'; END IF;
   IF operation='request_deletion' THEN
     IF c.owner_id<>u THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
     INSERT INTO data_studio.deletion_requests(contribution_id,requested_by) VALUES(c.id,u) ON CONFLICT DO NOTHING;
   ELSE
     IF data_studio.project_role(p,u) IS DISTINCT FROM 'pi' THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
     IF operation='retention_hold' THEN
       IF jsonb_typeof(payload->'hold') IS DISTINCT FROM 'boolean' OR length(trim(COALESCE(payload->>'reason','')))=0 THEN RAISE EXCEPTION 'STUDIO_REQUIRED'; END IF;
       UPDATE data_studio.deletion_requests SET hold=(payload->>'hold')::boolean WHERE contribution_id=c.id AND state IN ('PENDING','APPROVED');
     ELSE
       UPDATE data_studio.deletion_requests SET state='APPROVED',approved_by=u,approved_at=now() WHERE contribution_id=c.id AND state='PENDING' AND NOT hold;
     END IF;
     IF NOT FOUND THEN RAISE EXCEPTION 'STUDIO_CONFLICT'; END IF;
   END IF;
   INSERT INTO data_studio.events(actor,org_id,project_id,contribution_id,action,snapshot)
    VALUES(u,o,p,c.id,operation,jsonb_build_object('hold',payload->'hold','reason',left(payload->>'reason',2000),'policy','SYNTHETIC-RETENTION-1'));
   SELECT to_jsonb(d)-'lease' INTO answer FROM data_studio.deletion_requests d WHERE contribution_id=c.id;
   RETURN answer;
 END IF;
 -- Last-admin removal must leave an institutional recovery path.
 IF operation='revoke_member' AND payload->>'project_id' IS NULL AND EXISTS(
   SELECT 1 FROM data_studio.org_members WHERE org_id=(payload->>'org_id')::uuid AND user_id=(payload->>'id')::uuid AND active AND role='admin')
   AND (SELECT count(*) FROM data_studio.org_members WHERE org_id=(payload->>'org_id')::uuid AND active AND role='admin')<=1
 THEN RAISE EXCEPTION 'STUDIO_LAST_ADMIN'; END IF;
 RETURN data_studio.studio_command(operation,payload,request_id);
END $$;
CREATE FUNCTION public.studio_state() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s jsonb; u uuid:=auth.uid();
BEGIN
 IF NOT data_studio.session_active() THEN RAISE EXCEPTION 'STUDIO_AUTH'; END IF;
 s:=data_studio.studio_state();
 -- No worker lease or invitation token hash is exposed to clients.
 s:=jsonb_set(s,'{uploads}',COALESCE((SELECT jsonb_agg(value-'scan_lease'-'lease_until') FROM jsonb_array_elements(s->'uploads')),'[]'::jsonb));
 s:=jsonb_set(s,'{ai_runs}',COALESCE((SELECT jsonb_agg(value-'session_id') FROM jsonb_array_elements(s->'ai_runs')),'[]'::jsonb));
 RETURN s||jsonb_build_object(
 'deletions',COALESCE((SELECT jsonb_agg(to_jsonb(d)-'lease'-'lease_until') FROM data_studio.deletion_requests d WHERE data_studio.can_read(d.contribution_id,u)),'[]'::jsonb),
 'deliveries',COALESCE((SELECT jsonb_agg(to_jsonb(d)-'token_hash') FROM data_studio.invitation_deliveries d JOIN data_studio.invitations i ON i.id=d.invitation_id
 WHERE data_studio.org_admin(i.org_id,u) OR data_studio.project_role(i.project_id,u)='pi' OR
 (d.actor=u AND EXISTS(SELECT 1 FROM data_studio.platform_admins WHERE user_id=u AND expires_at>now()))),'[]'::jsonb));
END $$;
CREATE OR REPLACE FUNCTION public.studio_object_access(object_name text,writing boolean DEFAULT false) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT data_studio.session_active() AND EXISTS(SELECT 1 FROM data_studio.uploads x JOIN data_studio.contributions c ON c.id=x.contribution_id
 WHERE x.object_path=object_name AND data_studio.can_read(c.id,auth.uid()) AND c.status<>'WITHDRAWN'
 AND ((writing AND x.scan_state='PENDING' AND c.owner_id=auth.uid() AND c.status IN ('DRAFT','NEEDS_CLARIFICATION'))
 OR (NOT writing AND x.scan_state IN ('CLEAN','MOCK_CLEAN')))) $$;

-- Single-object worker leases prevent stale scan results and allow bounded retries after outages.
CREATE FUNCTION public.studio_scan_claim() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE x data_studio.uploads;
BEGIN
 PERFORM pg_advisory_xact_lock(7414001);
 SELECT a.* INTO x FROM data_studio.uploads a JOIN data_studio.contributions c ON c.id=a.contribution_id
 WHERE a.scan_state IN ('PENDING','ERROR') AND c.status<>'WITHDRAWN' AND (a.lease_until IS NULL OR a.lease_until<now())
 ORDER BY a.id LIMIT 1 FOR UPDATE OF a SKIP LOCKED;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE data_studio.uploads SET scan_lease=gen_random_uuid(),lease_until=now()+interval '2 minutes' WHERE id=x.id RETURNING * INTO x;
 RETURN to_jsonb(x);
END $$;
CREATE FUNCTION public.studio_scan_finish(upload_id uuid,lease uuid,verdict text,provider text,scanner_version text,actual_hash text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE x data_studio.uploads;
BEGIN
 PERFORM pg_advisory_xact_lock(7414001);
 SELECT * INTO x FROM data_studio.uploads WHERE id=upload_id FOR UPDATE;
 IF NOT FOUND OR x.scan_lease IS DISTINCT FROM lease OR x.lease_until<now() OR lease IS NULL THEN RAISE EXCEPTION 'STUDIO_CONFLICT'; END IF;
 IF provider IS NULL OR provider NOT IN ('mock','clamav') OR verdict IS NULL OR verdict NOT IN ('CLEAN','INFECTED','ERROR') OR scanner_version IS NULL OR length(trim(scanner_version))=0 OR length(scanner_version)>200 THEN RAISE EXCEPTION 'STUDIO_INVALID'; END IF;
 IF EXISTS(SELECT 1 FROM data_studio.contributions WHERE id=x.contribution_id AND status='WITHDRAWN') THEN verdict:='ERROR'; END IF;
 IF actual_hash IS DISTINCT FROM x.sha256 THEN verdict:='ERROR'; END IF;
 IF verdict='CLEAN' AND provider='mock' THEN verdict:='MOCK_CLEAN'; END IF;
 UPDATE data_studio.uploads SET scan_state=verdict,scan_provider=provider,scan_version=scanner_version,scanned_at=now(),scan_lease=NULL,
   lease_until=CASE WHEN verdict='ERROR' THEN now()+interval '5 minutes' ELSE NULL END WHERE id=x.id;
 INSERT INTO data_studio.file_events(upload_id,action,provider,scanner_version,sha256) VALUES(x.id,verdict,provider,scanner_version,x.sha256);
 RETURN jsonb_build_object('id',x.id,'scan_state',verdict);
END $$;

CREATE FUNCTION public.studio_deletion_claim() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d data_studio.deletion_requests;
BEGIN
 PERFORM pg_advisory_xact_lock(7414001);
 SELECT * INTO d FROM data_studio.deletion_requests WHERE state IN ('APPROVED','PURGING') AND NOT hold AND eligible_at<=now()
 AND (lease_until IS NULL OR lease_until<now()) ORDER BY requested_at LIMIT 1 FOR UPDATE SKIP LOCKED;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE data_studio.deletion_requests SET state='PURGING',lease=gen_random_uuid(),lease_until=now()+interval '2 minutes' WHERE contribution_id=d.contribution_id RETURNING * INTO d;
 RETURN to_jsonb(d)||jsonb_build_object('paths',COALESCE((SELECT jsonb_agg(object_path) FROM data_studio.uploads WHERE contribution_id=d.contribution_id),'[]'::jsonb));
END $$;
CREATE FUNCTION public.studio_deletion_finish(item_id uuid,lease_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d data_studio.deletion_requests;
BEGIN
 PERFORM pg_advisory_xact_lock(7414001);
 SELECT * INTO d FROM data_studio.deletion_requests WHERE contribution_id=item_id FOR UPDATE;
 IF NOT FOUND OR d.state<>'PURGING' OR d.lease IS DISTINCT FROM lease_id OR lease_id IS NULL OR d.lease_until<now() OR d.hold THEN RAISE EXCEPTION 'STUDIO_CONFLICT'; END IF;
 IF EXISTS(SELECT 1 FROM storage.objects s JOIN data_studio.uploads u ON s.name=u.object_path WHERE s.bucket_id='studio-quarantine' AND u.contribution_id=item_id) THEN RAISE EXCEPTION 'STUDIO_STORAGE_REMAINS'; END IF;
 -- Retain identifiers, rights and hash receipts, but erase every Studio copy of contributor content.
 UPDATE data_studio.contributions SET content='{}',updated_at=now(),revision=revision+1 WHERE id=item_id AND status='WITHDRAWN';
 IF NOT FOUND THEN RAISE EXCEPTION 'STUDIO_CONFLICT'; END IF;
 UPDATE data_studio.events SET snapshot=jsonb_build_object('redacted',true,'policy',d.policy_version) WHERE contribution_id=item_id;
 UPDATE data_studio.requests SET body=jsonb_build_object('redacted',true),result=jsonb_build_object('id',item_id,'redacted',true)
 WHERE body->'payload'->>'id'=item_id::text OR result->>'id'=item_id::text OR result->>'contribution_id'=item_id::text;
 UPDATE data_studio.ai_runs SET result=NULL,state='CANCELLED' WHERE contribution_id=item_id;
 UPDATE data_studio.handoffs SET packet=jsonb_build_object('redacted',true),state='WITHDRAWN' WHERE contribution_id=item_id;
 INSERT INTO data_studio.file_events(upload_id,action,sha256) SELECT id,'DELETED',sha256 FROM data_studio.uploads WHERE contribution_id=item_id;
 UPDATE data_studio.uploads SET scan_state='DELETED',scan_lease=NULL,lease_until=NULL WHERE contribution_id=item_id;
 UPDATE data_studio.deletion_requests SET state='PURGED',purged_at=now(),lease=NULL,lease_until=NULL WHERE contribution_id=item_id;
END $$;

CREATE FUNCTION public.studio_invitation_prepare(invitation_id uuid,delivery_request uuid,email_provider text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE i data_studio.invitations; d data_studio.invitation_deliveries; token text; u uuid:=auth.uid();
BEGIN
 IF NOT data_studio.session_active() OR delivery_request IS NULL OR email_provider NOT IN ('mock','resend') THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
 PERFORM pg_advisory_xact_lock(7414001);
 SELECT * INTO i FROM data_studio.invitations WHERE id=invitation_id FOR UPDATE;
 IF NOT FOUND OR i.revoked OR i.accepted_by IS NOT NULL OR NOT (
 data_studio.org_admin(i.org_id,u) OR COALESCE(data_studio.project_role(i.project_id,u)='pi',false) OR
 (i.project_id IS NULL AND EXISTS(SELECT 1 FROM data_studio.platform_admins WHERE user_id=u AND expires_at>now())
 AND NOT EXISTS(SELECT 1 FROM data_studio.org_members WHERE org_id=i.org_id AND active))) THEN RAISE EXCEPTION 'STUDIO_DENIED'; END IF;
 SELECT * INTO d FROM data_studio.invitation_deliveries WHERE actor=u AND request_id=delivery_request;
 IF FOUND THEN
   IF d.invitation_id<>i.id OR d.provider<>email_provider THEN RAISE EXCEPTION 'STUDIO_CONFLICT'; END IF;
   RETURN jsonb_build_object('id',d.id,'state',d.state,'replayed',true);
 END IF;
 IF (SELECT count(*) FROM data_studio.invitation_deliveries WHERE actor=u AND created_at>now()-interval '1 day')>=50 OR
 (SELECT count(*) FROM data_studio.invitation_deliveries WHERE invitation_deliveries.invitation_id=i.id AND created_at>now()-interval '1 hour')>=5 THEN RAISE EXCEPTION 'STUDIO_LIMIT'; END IF;
 token:=gen_random_uuid()::text||gen_random_uuid()::text;
 UPDATE data_studio.invitations SET token_hash=encode(sha256(convert_to(token,'UTF8')),'hex'),expires_at=now()+interval '7 days' WHERE id=i.id RETURNING * INTO i;
 INSERT INTO data_studio.invitation_deliveries(invitation_id,actor,request_id,provider,token_hash) VALUES(i.id,u,delivery_request,email_provider,i.token_hash) RETURNING * INTO d;
 INSERT INTO data_studio.events(actor,org_id,project_id,action,snapshot) VALUES(u,i.org_id,i.project_id,'invitation_delivery_prepared',jsonb_build_object('id',d.id,'invitation_id',i.id));
 RETURN jsonb_build_object('id',d.id,'token',token,'email',i.email,'expires_at',i.expires_at);
END $$;
CREATE FUNCTION public.studio_invitation_finish(delivery_id uuid,succeeded boolean,message_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d data_studio.invitation_deliveries; i data_studio.invitations; s text;
BEGIN
 PERFORM pg_advisory_xact_lock(7414001);
 SELECT * INTO d FROM data_studio.invitation_deliveries WHERE id=delivery_id FOR UPDATE;
 IF NOT FOUND OR d.state<>'PREPARED' THEN RAISE EXCEPTION 'STUDIO_CONFLICT'; END IF;
 SELECT * INTO i FROM data_studio.invitations WHERE id=d.invitation_id;
 s:=CASE WHEN i.revoked OR i.token_hash<>d.token_hash THEN 'CANCELLED' WHEN NOT succeeded THEN 'FAILED' WHEN d.provider='mock' THEN 'MOCK_SENT' ELSE 'SENT' END;
 UPDATE data_studio.invitation_deliveries SET state=s,provider_message_id=left(message_id,200),completed_at=now() WHERE id=d.id;
 RETURN jsonb_build_object('id',d.id,'state',s);
END $$;

REVOKE ALL ON FUNCTION public.studio_command(text,jsonb,uuid),public.studio_state(),public.studio_scan_claim(),public.studio_scan_finish(uuid,uuid,text,text,text,text),public.studio_deletion_claim(),public.studio_deletion_finish(uuid,uuid),public.studio_invitation_prepare(uuid,uuid,text),public.studio_invitation_finish(uuid,boolean,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.studio_command(text,jsonb,uuid),public.studio_state(),public.studio_invitation_prepare(uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.studio_scan_claim(),public.studio_scan_finish(uuid,uuid,text,text,text,text),public.studio_deletion_claim(),public.studio_deletion_finish(uuid,uuid),public.studio_invitation_finish(uuid,boolean,text) TO service_role;

ALTER TABLE data_studio.ai_runs ADD COLUMN session_id uuid DEFAULT NULLIF(auth.jwt()->>'session_id','')::uuid;
ALTER FUNCTION public.studio_ai_finish(uuid,jsonb,text,integer,boolean) SET SCHEMA data_studio;
REVOKE ALL ON FUNCTION data_studio.studio_ai_finish(uuid,jsonb,text,integer,boolean) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.studio_ai_finish(run_id uuid,output jsonb,model_name text,duration_ms integer,failed boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(7414001);
 IF NOT EXISTS(SELECT 1 FROM data_studio.ai_runs a JOIN auth.sessions s ON s.id=a.session_id AND s.user_id=a.actor
 JOIN auth.users u ON u.id=a.actor WHERE a.id=run_id AND (s.not_after IS NULL OR s.not_after>now()) AND (u.banned_until IS NULL OR u.banned_until<now())) THEN
   UPDATE data_studio.ai_runs SET state='CANCELLED',result=NULL WHERE id=run_id AND state='RUNNING';
   RETURN jsonb_build_object('state','CANCELLED');
 END IF;
 RETURN data_studio.studio_ai_finish(run_id,output,model_name,duration_ms,failed);
END $$;
REVOKE ALL ON FUNCTION public.studio_ai_finish(uuid,jsonb,text,integer,boolean) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.studio_ai_finish(uuid,jsonb,text,integer,boolean) TO service_role;
