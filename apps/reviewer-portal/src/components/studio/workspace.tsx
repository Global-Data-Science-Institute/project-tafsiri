"use client";
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type FormEvent,
  type ReactNode,
} from "react";
import { createBrowserSupabase } from "@/lib/supabase/browser";

type Row = {
  id: string;
  name?: string;
  title?: string;
  role?: string;
  org_id?: string;
  status?: string;
};
type Project = Row & {
  org_id: string;
  external_ai: boolean;
  language_id: string | null;
  variety_id: string | null;
  proposal_id: string | null;
};
type Campaign = Row & {
  project_id: string;
  category: string;
  template: { key: string; label: string; required: boolean }[];
  target_count: number;
};
type Contribution = Row & {
  campaign_id: string;
  owner_id: string;
  content: Record<string, string>;
  consent: Record<string, boolean>;
  revision: number;
  status: string;
};
type Upload = Row & {
  contribution_id: string;
  mime: string;
  state: string;
  size_bytes: number;
};
type Run = Row & {
  contribution_id: string;
  provider: string;
  model: string;
  state: string;
  verification: string;
  result: {
    observations?: string[];
    questions?: string[];
    candidates?: string[];
    uncertainty?: string;
    error?: string;
  } | null;
};
type State = {
  user_id: string;
  platform_admin: boolean;
  organizations: Row[];
  partners: Row[];
  projects: Project[];
  campaigns: Campaign[];
  proposals: Row[];
  languages: Row[];
  varieties: Row[];
  contributions: Contribution[];
  uploads: Upload[];
  ai_runs: Run[];
  handoffs: (Row & { contribution_id: string; state: string })[];
  invitations: (Row & {
    email: string;
    project_id: string | null;
    revoked: boolean;
    accepted_by: string | null;
  })[];
  members: {
    project_id: string;
    user_id: string;
    email: string;
    role: string;
    active: boolean;
  }[];
  org_members: {
    org_id: string;
    user_id: string;
    email: string;
    role: string;
    active: boolean;
  }[];
  events: {
    id: number;
    action: string;
    created_at: string;
    contribution_id: string | null;
    snapshot: { payload?: { reason?: string } };
  }[];
};
type Command = (
  operation: string,
  payload: Record<string, unknown>,
) => Promise<Record<string, unknown>>;
const categories = {
  WORD: "Vocabulary & definitions",
  SENTENCE_PAIR: "Translation & sentence pairs",
  PROVERB_IDIOM: "Proverbs & idioms",
  NARRATIVE: "Narratives & oral histories",
  PRONUNCIATION: "Pronunciation",
  CONVERSATION: "Conversational audio",
  DOCUMENT: "Documents & dictionaries",
  ANNOTATION: "Linguistic annotations",
  CULTURAL_CONTEXT: "Cultural context",
};
const consentLabels: Record<string, string> = {
  internal_research: "Internal research",
  human_review: "Human review",
  training: "Potential model training",
  public_display: "Public display",
  redistribution: "Redistribution",
  commercial: "Commercial use",
  external_ai: "External AI processing of the text I supply",
};
function Field({
  label,
  name,
  value = "",
  type = "text",
  required = false,
}: {
  label: string;
  name: string;
  value?: string;
  type?: string;
  required?: boolean;
}) {
  return (
    <label>
      {label}
      <input
        name={name}
        type={type}
        defaultValue={value}
        required={required}
        maxLength={type === "email" ? 254 : 2000}
      />
    </label>
  );
}
function ActionForm({
  title,
  button,
  action,
  children,
}: {
  title: string;
  button: string;
  action: (f: FormData) => Promise<unknown>;
  children: ReactNode;
}) {
  const [busy, setBusy] = useState(false);
  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setBusy(true);
    try {
      await action(new FormData(e.currentTarget));
    } catch {
      /* Workspace displays errors. */
    } finally {
      setBusy(false);
    }
  }
  return (
    <section className="studio-card">
      <h3>{title}</h3>
      <form onSubmit={submit}>
        {children}
        <button disabled={busy}>{busy ? "Working…" : button}</button>
      </form>
    </section>
  );
}
const value = (f: FormData, key: string) => String(f.get(key) ?? "");

export default function Studio({ invitation }: { invitation: string }) {
  const [state, setState] = useState<State | null>(null),
    [auth, setAuth] = useState(false),
    [message, setMessage] = useState("");
  const [tab, setTab] = useState("overview"),
    [org, setOrg] = useState(""),
    [project, setProject] = useState(""),
    [inviteLink, setInviteLink] = useState("");
  const [campaign, setCampaign] = useState(""),
    [editing, setEditing] = useState<string | null>(null);
  const load = useCallback(async () => {
    const response = await fetch("/api/studio", { cache: "no-store" });
    if (response.status === 401) {
      setAuth(true);
      return;
    }
    if (!response.ok) {
      setMessage(
        "Workspace unavailable. Ask your institutional administrator to check access.",
      );
      return;
    }
    setState(await response.json());
    setAuth(false);
  }, []);
  useEffect(() => {
    const controller = new AbortController();
    fetch("/api/studio", { cache: "no-store", signal: controller.signal })
      .then(async (response) => {
        if (response.status === 401) {
          setAuth(true);
          return;
        }
        if (!response.ok) {
          setMessage(
            "Workspace unavailable. Ask your administrator to check access.",
          );
          return;
        }
        setState(await response.json());
      })
      .catch((error) => {
        if (error.name !== "AbortError")
          setMessage("Unable to load the workspace. Please retry.");
      });
    return () => controller.abort();
  }, []);
  const command: Command = async (operation, payload) => {
    const response = await fetch("/api/studio", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        operation,
        payload,
        request_id: crypto.randomUUID(),
      }),
    });
    const result = await response.json();
    if (!response.ok) {
      setMessage(`${result.message} (${result.error})`);
      throw new Error(result.error);
    }
    if (result.token)
      setInviteLink(
        `${location.origin}/studio?invite=${encodeURIComponent(result.token)}`,
      );
    setMessage(
      "Saved. Collection acceptance is separate from linguistic verification.",
    );
    await load();
    return result;
  };
  const safeCommand = (op: string, data: Record<string, unknown>) => {
    void command(op, data).catch(() => {});
  };
  const selectedOrg = org || state?.organizations[0]?.id || "";
  const orgAdmin = state?.organizations.some(
    (o) => o.id === selectedOrg && o.role === "admin",
  );
  const availableProjects =
    state?.projects.filter(
      (p) =>
        !selectedOrg ||
        p.org_id === selectedOrg ||
        !state.organizations.some((o) => o.id === p.org_id),
    ) ?? [];
  const selectedProject =
    availableProjects.find((p) => p.id === project) ?? availableProjects[0];
  const campaigns =
    state?.campaigns.filter((c) => c.project_id === selectedProject?.id) ?? [];
  const selectedCampaign =
    campaigns.find((c) => c.id === campaign) ?? campaigns[0];
  const items =
    state?.contributions.filter((c) =>
      campaigns.some((k) => k.id === c.campaign_id),
    ) ?? [];
  const editable = state?.contributions.find((c) => c.id === editing);
  const pi = selectedProject?.role === "pi",
    researcher = pi || selectedProject?.role === "researcher";
  return (
    <main className="studio-shell">
      <header className="studio-header">
        <div>
          <p className="studio-eyebrow">GDSI · Project Tafsiri</p>
          <h1>Research workspace</h1>
          <p>Build language resources together, with provenance and care.</p>
        </div>
        {state && (
          <button
            className="secondary"
            onClick={async () => {
              await createBrowserSupabase().auth.signOut();
              setState(null);
              setAuth(true);
            }}
          >
            Sign out
          </button>
        )}
      </header>
      <div className="studio-notice">
        Synthetic acceptance environment · Use clearly labeled test material
        only. No real partner onboarding is approved.
      </div>
      <p role="status" aria-live="polite" className="studio-message">
        {message}
      </p>
      {auth ? (
        <ActionForm
          title="Welcome to Tafsiri"
          button="Sign in"
          action={async (f) => {
            const { error } =
              await createBrowserSupabase().auth.signInWithPassword({
                email: value(f, "email"),
                password: value(f, "password"),
              });
            if (error) {
              setMessage("Unable to sign in. Check your credentials.");
              return;
            }
            await load();
          }}
        >
          <p>
            Sign in with the verified email address on your institutional
            invitation.
          </p>
          <Field label="Email" name="email" type="email" required />
          <Field label="Password" name="password" type="password" required />
          <details>
            <summary>New here?</summary>
            <p>
              Use your invitation email to create an account, then confirm the
              verification email.
            </p>
            <button
              type="button"
              className="secondary"
              onClick={async (e) => {
                const form = e.currentTarget.closest("form")!;
                const f = new FormData(form);
                const { error } = await createBrowserSupabase().auth.signUp({
                  email: value(f, "email"),
                  password: value(f, "password"),
                });
                setMessage(
                  error
                    ? "Account could not be created. Check your email and password."
                    : "Check your email to verify your account, then sign in and accept your invitation.",
                );
              }}
            >
              Create account
            </button>
          </details>
        </ActionForm>
      ) : !state ? (
        <p>Loading your workspace…</p>
      ) : (
        <>
          {(invitation ||
            (!state.organizations.length && !state.projects.length)) && (
            <ActionForm
              title="Accept your invitation"
              button="Join workspace"
              action={(f) =>
                command("accept_invitation", { token: value(f, "token") })
              }
            >
              <p>
                Your invitation is bound to your verified email. A project
                invitation shares only that project.
              </p>
              <Field
                label="Invitation token"
                name="token"
                value={invitation}
                required
              />
            </ActionForm>
          )}
          <nav className="studio-tabs" aria-label="Workspace sections">
            {[
              "overview",
              "collect",
              "intake",
              "administration",
              ...(state.platform_admin ? ["GDSI oversight"] : []),
            ].map((t) => (
              <button
                key={t}
                aria-current={tab === t ? "page" : undefined}
                onClick={() => setTab(t)}
              >
                {t}
              </button>
            ))}
          </nav>
          {tab !== "GDSI oversight" && (
            <div className="studio-selectors">
              <label>
                Organization
                <select
                  value={selectedOrg}
                  onChange={(e) => {
                    setOrg(e.target.value);
                    setProject("");
                    setEditing(null);
                  }}
                >
                  <option value="">Shared projects</option>
                  {state.organizations.map((o) => (
                    <option key={o.id} value={o.id}>
                      {o.name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Project
                <select
                  value={selectedProject?.id ?? ""}
                  onChange={(e) => {
                    setProject(e.target.value);
                    setCampaign("");
                    setEditing(null);
                  }}
                >
                  <option value="">Choose a project</option>
                  {availableProjects.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.title}
                    </option>
                  ))}
                </select>
              </label>
            </div>
          )}
          {inviteLink && (
            <aside className="studio-card">
              <h3>Invitation ready</h3>
              <p>
                Share this private link with the intended recipient. No email
                has been sent automatically.
              </p>
              <input
                aria-label="Invitation link"
                readOnly
                value={inviteLink}
                onFocus={(e) => e.target.select()}
              />
              <button className="secondary" onClick={() => setInviteLink("")}>
                Dismiss private link
              </button>
            </aside>
          )}
          {tab === "overview" && (
            <>
              <div className="studio-metrics">
                <article>
                  <strong>{campaigns.length}</strong>
                  <span>Collection campaigns</span>
                </article>
                <article>
                  <strong>{items.length}</strong>
                  <span>Visible contributions</span>
                </article>
                <article>
                  <strong>
                    {
                      items.filter(
                        (c) => c.status === "ACCEPTED_FOR_RESEARCH_INTAKE",
                      ).length
                    }
                  </strong>
                  <span>Accepted for intake</span>
                </article>
                <article>
                  <strong>
                    {
                      state.ai_runs.filter((r) =>
                        items.some((c) => c.id === r.contribution_id),
                      ).length
                    }
                  </strong>
                  <span>AI requests</span>
                </article>
              </div>
              <section className="studio-card">
                <h2>
                  {selectedProject?.title ?? "Start your research workspace"}
                </h2>
                <p>
                  Set up your organization, choose or propose a language, invite
                  your team, then create a collection campaign. You do not need
                  an existing corpus.
                </p>
                <p>
                  Collection progress does not establish model readiness. Every
                  contribution remains unverified until independent qualified
                  review.
                </p>
                {campaigns.map((c) => (
                  <div className="studio-progress" key={c.id}>
                    <strong>{c.title}</strong>
                    <span>
                      {items.filter((i) => i.campaign_id === c.id).length} /{" "}
                      {c.target_count} collection target
                    </span>
                    <progress
                      aria-label={`${c.title} progress`}
                      value={items.filter((i) => i.campaign_id === c.id).length}
                      max={c.target_count}
                    />
                  </div>
                ))}
              </section>
            </>
          )}
          {tab === "collect" && (
            <>
              {selectedCampaign ? (
                <>
                  <label>
                    Collection campaign
                    <select
                      value={selectedCampaign.id}
                      onChange={(e) => {
                        setCampaign(e.target.value);
                        setEditing(null);
                      }}
                    >
                      {campaigns.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.title}
                        </option>
                      ))}
                    </select>
                  </label>
                  <ContributionForm
                    key={`${editable?.id ?? "new"}-${editable?.revision ?? selectedCampaign.id}`}
                    campaign={
                      editable
                        ? state.campaigns.find(
                            (c) => c.id === editable.campaign_id,
                          )!
                        : selectedCampaign
                    }
                    item={editable}
                    command={command}
                    onSaved={(id) => setEditing(id)}
                  />
                  <ContributionList
                    items={items.filter((i) => i.owner_id === state.user_id)}
                    state={state}
                    researcher={false}
                    command={command}
                    onEdit={(id) => {
                      setEditing(id);
                      window.scrollTo({ top: 0, behavior: "smooth" });
                    }}
                    refresh={load}
                    message={setMessage}
                  />
                </>
              ) : (
                <section className="studio-card">
                  <h2>No campaign yet</h2>
                  <p>
                    Your project lead can create a collection campaign in
                    Administration.
                  </p>
                </section>
              )}
            </>
          )}
          {tab === "intake" && (
            <>
              <h2>Contribution tracking</h2>
              <p>
                Original submissions, consent and AI proposals stay separate.
                Intake acceptance grants no canonical or training approval.
              </p>
              <ContributionList
                items={items}
                state={state}
                researcher={researcher}
                command={command}
                onEdit={(id) => {
                  setEditing(id);
                  setTab("collect");
                }}
                refresh={load}
                message={setMessage}
              />
            </>
          )}
          {tab === "administration" && (
            <div className="studio-grid">
              {!orgAdmin && selectedProject && (
                <ActionForm
                  title="Propose a language"
                  button="Submit language proposal"
                  action={(f) =>
                    command("propose_language", {
                      org_id: selectedProject.org_id,
                      name: value(f, "name"),
                      description: value(f, "description"),
                    })
                  }
                >
                  <p>
                    Your institution will review this proposal. It does not
                    change the current project scope or create an approved
                    language.
                  </p>
                  <Field label="Community language name" name="name" required />
                  <Field
                    label="Scope and community context"
                    name="description"
                    required
                  />
                </ActionForm>
              )}
              {orgAdmin && (
                <>
                  <ActionForm
                    title="Organization profile"
                    button="Save profile"
                    action={(f) =>
                      command("update_org", {
                        org_id: selectedOrg,
                        name: value(f, "name"),
                        description: value(f, "description"),
                      })
                    }
                  >
                    <Field
                      label="Organization name"
                      name="name"
                      value={
                        state.organizations.find((o) => o.id === selectedOrg)
                          ?.name
                      }
                      required
                    />
                    <Field label="Research focus" name="description" />
                  </ActionForm>
                  <ActionForm
                    title="Propose a language"
                    button="Submit language proposal"
                    action={(f) =>
                      command("propose_language", {
                        org_id: selectedOrg,
                        name: value(f, "name"),
                        description: value(f, "description"),
                      })
                    }
                  >
                    <p>
                      A proposal enables planning, not an approved language
                      identity.
                    </p>
                    <Field
                      label="Community language name"
                      name="name"
                      required
                    />
                    <Field
                      label="Scope and community context"
                      name="description"
                      required
                    />
                  </ActionForm>
                  <section className="studio-card">
                    <h3>Language proposals</h3>
                    {state.proposals
                      .filter((p) => p.org_id === selectedOrg)
                      .map((p) => (
                        <article key={p.id}>
                          <p>
                            {p.name} · {p.status}
                          </p>
                          {p.status === "PENDING" && (
                            <>
                              <button
                                onClick={() =>
                                  safeCommand("process_language", {
                                    org_id: selectedOrg,
                                    id: p.id,
                                    status: "COLLECTION_ALLOWED",
                                  })
                                }
                              >
                                Allow collection planning
                              </button>
                              <button
                                className="secondary"
                                onClick={() =>
                                  safeCommand("process_language", {
                                    org_id: selectedOrg,
                                    id: p.id,
                                    status: "REJECTED",
                                  })
                                }
                              >
                                Reject proposal
                              </button>
                            </>
                          )}
                        </article>
                      ))}
                  </section>
                  <ActionForm
                    title="Create research project"
                    button="Create project"
                    action={(f) => {
                      const [kind, id] = value(f, "scope").split(":");
                      return command("create_project", {
                        org_id: selectedOrg,
                        title: value(f, "title"),
                        [`${kind}_id`]: id,
                      });
                    }}
                  >
                    <Field label="Project title" name="title" required />
                    <label>
                      Language or variety
                      <select name="scope" required defaultValue="">
                        <option value="">Choose a scope</option>
                        {state.languages.map((l) => (
                          <option key={l.id} value={`language:${l.id}`}>
                            {l.name}
                          </option>
                        ))}
                        {state.varieties.map((l) => (
                          <option key={l.id} value={`variety:${l.id}`}>
                            {l.name} (variety)
                          </option>
                        ))}
                        {state.proposals
                          .filter(
                            (p) =>
                              p.org_id === selectedOrg &&
                              p.status === "COLLECTION_ALLOWED",
                          )
                          .map((l) => (
                            <option key={l.id} value={`proposal:${l.id}`}>
                              {l.name} (proposal, unverified)
                            </option>
                          ))}
                      </select>
                    </label>
                  </ActionForm>
                  <ActionForm
                    title="Invite organization member"
                    button="Create organization invitation"
                    action={(f) =>
                      command("invite", {
                        org_id: selectedOrg,
                        email: value(f, "email"),
                        role: value(f, "role"),
                      })
                    }
                  >
                    <Field
                      label="Member email"
                      name="email"
                      type="email"
                      required
                    />
                    <label>
                      Organization role
                      <select name="role">
                        <option value="member">Member</option>
                        <option value="admin">Administrator</option>
                      </select>
                    </label>
                  </ActionForm>
                </>
              )}
              {pi && selectedProject && (
                <>
                  <ActionForm
                    title="Invite project collaborator"
                    button="Create project invitation"
                    action={(f) =>
                      command("invite", {
                        project_id: selectedProject.id,
                        email: value(f, "email"),
                        role: value(f, "role"),
                      })
                    }
                  >
                    <p>
                      Invite a colleague from your institution or another
                      organization. Access is limited to this project and can be
                      revoked.
                    </p>
                    <Field
                      label="Collaborator email"
                      name="email"
                      type="email"
                      required
                    />
                    <label>
                      Project role
                      <select name="role">
                        <option value="contributor">
                          Contributor — own submissions
                        </option>
                        <option value="researcher">
                          Researcher — project intake
                        </option>
                        <option value="pi">
                          Principal investigator — project management
                        </option>
                      </select>
                    </label>
                  </ActionForm>
                  <ActionForm
                    title="Create collection campaign"
                    button="Create campaign"
                    action={(f) =>
                      command("create_campaign", {
                        project_id: selectedProject.id,
                        title: value(f, "title"),
                        category: value(f, "category"),
                        target_count: Number(value(f, "target")),
                        template: value(f, "questions")
                          .split("\n")
                          .map((x) => x.trim())
                          .filter(Boolean)
                          .map((label, i) => ({
                            key: `question_${i + 1}`,
                            label: label.replace(/\?$/, ""),
                            required: !label.endsWith("?"),
                          })),
                      })
                    }
                  >
                    <Field label="Campaign title" name="title" required />
                    <label>
                      Collection category
                      <select name="category">
                        {Object.entries(categories).map(([key, label]) => (
                          <option key={key} value={key}>
                            {label}
                          </option>
                        ))}
                      </select>
                    </label>
                    <Field
                      label="Collection target"
                      name="target"
                      type="number"
                      value="10"
                      required
                    />
                    <label>
                      Additional questions, one per line
                      <textarea
                        name="questions"
                        maxLength={1000}
                        placeholder="Speaker context&#10;Usage setting?"
                      />
                    </label>
                    <small>
                      Questions are required unless their line ends with ?. Up
                      to 12 questions, 100 characters each.
                    </small>
                  </ActionForm>
                  <section className="studio-card">
                    <h3>Project AI policy</h3>
                    <p>
                      External processing is{" "}
                      {selectedProject.external_ai ? "enabled" : "disabled"}.
                      Each contribution also needs its owner explicit
                      authorization. A platform operator must configure the
                      provider before it can run.
                    </p>
                    <button
                      onClick={() =>
                        safeCommand("project_settings", {
                          project_id: selectedProject.id,
                          external_ai: !selectedProject.external_ai,
                        })
                      }
                    >
                      {selectedProject.external_ai
                        ? "Disable external AI"
                        : "Enable external AI"}
                    </button>
                  </section>
                  <section className="studio-card">
                    <h3>Project team</h3>
                    {state.members
                      .filter((m) => m.project_id === selectedProject.id)
                      .map((m) => (
                        <article key={m.user_id}>
                          <p>
                            {m.user_id} · {m.role} ·{" "}
                            {m.active ? "Active" : "Revoked"}
                          </p>
                          {m.active && m.user_id !== state.user_id && (
                            <button
                              className="secondary"
                              onClick={() =>
                                safeCommand("revoke_member", {
                                  project_id: selectedProject.id,
                                  id: m.user_id,
                                })
                              }
                            >
                              Revoke project access
                            </button>
                          )}
                        </article>
                      ))}
                  </section>
                </>
              )}
              {orgAdmin && (
                <section className="studio-card">
                  <h3>Organization team</h3>
                  {state.org_members
                    .filter((m) => m.org_id === selectedOrg)
                    .map((m) => (
                      <article key={m.user_id}>
                        <p>
                          {m.user_id} · {m.role} ·{" "}
                          {m.active ? "Active" : "Revoked"}
                        </p>
                        {m.active && m.user_id !== state.user_id && (
                          <button
                            className="secondary"
                            onClick={() =>
                              safeCommand("revoke_member", {
                                org_id: selectedOrg,
                                id: m.user_id,
                              })
                            }
                          >
                            Revoke organization access
                          </button>
                        )}
                      </article>
                    ))}
                </section>
              )}
              <section className="studio-card">
                <h3>Invitations</h3>
                {state.invitations.map((i) => (
                  <article key={i.id}>
                    <p>
                      {i.email} · {i.role} ·{" "}
                      {i.revoked
                        ? "Revoked"
                        : i.accepted_by
                          ? "Accepted"
                          : "Pending"}
                    </p>
                    {!i.revoked && !i.accepted_by && (
                      <button
                        className="secondary"
                        onClick={() =>
                          safeCommand("revoke_invitation", {
                            org_id: i.org_id,
                            project_id: i.project_id,
                            id: i.id,
                          })
                        }
                      >
                        Revoke invitation
                      </button>
                    )}
                  </article>
                ))}
              </section>
              <section className="studio-card">
                <h3>Recent audit activity</h3>
                {state.events.slice(0, 20).map((e) => (
                  <p key={e.id}>
                    {e.action.replaceAll("_", " ")} ·{" "}
                    {new Date(e.created_at).toLocaleString()}
                  </p>
                ))}
              </section>
            </div>
          )}
          {tab === "GDSI oversight" && state.platform_admin && (
            <div className="studio-grid">
              <ActionForm
                title="Invite a partner institution"
                button="Create partner invitation"
                action={(f) =>
                  command("onboard", {
                    name: value(f, "name"),
                    email: value(f, "email"),
                  })
                }
              >
                <p>
                  Partner onboarding metadata only. This role does not grant
                  access to private project content.
                </p>
                <Field label="Institution name" name="name" required />
                <Field
                  label="Institution administrator email"
                  name="email"
                  type="email"
                  required
                />
              </ActionForm>
              <section className="studio-card">
                <h2>Partner organizations</h2>
                {state.partners.map((p) => (
                  <p key={p.id}>{p.name}</p>
                ))}
              </section>
            </div>
          )}
        </>
      )}
    </main>
  );
}

function ContributionForm({
  campaign,
  item,
  command,
  onSaved,
}: {
  campaign: Campaign;
  item?: Contribution;
  command: Command;
  onSaved: (id: string) => void;
}) {
  return (
    <ActionForm
      title={item ? "Resume contribution" : "New contribution"}
      button="Save draft"
      action={async (f) => {
        const content: Record<string, string> = {};
        for (const key of [
          "text",
          "translation",
          "counterpart_scope",
          "source",
          "method",
          "context",
          ...campaign.template.map((t) => t.key),
        ])
          content[key] = value(f, key);
        const consent = Object.fromEntries(
          Object.keys(consentLabels).map((k) => [k, f.get(k) === "on"]),
        );
        const result = await command("save", {
          id: item?.id,
          revision: item?.revision,
          campaign_id: campaign.id,
          content,
          consent,
        });
        onSaved(String(result.id));
      }}
    >
      <p>
        {categories[campaign.category as keyof typeof categories]} · Original
        text is preserved. Mark all examples as synthetic.
      </p>
      <label>
        Original text or recording description
        <textarea
          name="text"
          defaultValue={item?.content.text ?? ""}
          maxLength={20000}
          rows={5}
        />
      </label>
      <Field
        label="Translation or definition (if supplied)"
        name="translation"
        value={item?.content.translation}
      />
      <Field
        label="Translation / definition language label"
        name="counterpart_scope"
        value={item?.content.counterpart_scope}
      />
      <Field
        label="Source and provenance"
        name="source"
        value={item?.content.source}
      />
      <Field
        label="Collection method"
        name="method"
        value={item?.content.method}
      />
      <Field
        label="Cultural context or uncertainty"
        name="context"
        value={item?.content.context}
      />
      {campaign.template.map((t) => (
        <Field
          key={t.key}
          label={`${t.label}${t.required ? " (required to submit)" : ""}`}
          name={t.key}
          value={item?.content[t.key]}
        />
      ))}
      <fieldset>
        <legend>My permitted uses · Consent version 1</legend>
        <p>
          Choose each purpose independently. Internal research and human review
          are needed to submit. Your choices are assertions for later rights
          review; they do not approve training or commercial use.
        </p>
        {Object.entries(consentLabels).map(([key, label]) => (
          <label className="studio-check" key={key}>
            <input
              type="checkbox"
              name={key}
              defaultChecked={item?.consent[key] ?? false}
            />
            {label}
          </label>
        ))}
      </fieldset>
    </ActionForm>
  );
}

function ContributionList({
  items,
  state,
  researcher,
  command,
  onEdit,
  refresh,
  message,
}: {
  items: Contribution[];
  state: State;
  researcher: boolean;
  command: Command;
  onEdit: (id: string) => void;
  refresh: () => Promise<void>;
  message: (text: string) => void;
}) {
  if (!items.length)
    return (
      <section className="studio-card">
        <h3>No contributions yet</h3>
        <p>
          Save your first draft in Collect. You can return to it before
          submitting.
        </p>
      </section>
    );
  return (
    <div className="studio-grid">
      {items.map((item) => (
        <ContributionCard
          key={item.id}
          item={item}
          state={state}
          researcher={researcher}
          command={command}
          onEdit={onEdit}
          refresh={refresh}
          message={message}
        />
      ))}
    </div>
  );
}
function ContributionCard({
  item,
  state,
  researcher,
  command,
  onEdit,
  refresh,
  message,
}: {
  item: Contribution;
  state: State;
  researcher: boolean;
  command: Command;
  onEdit: (id: string) => void;
  refresh: () => Promise<void>;
  message: (text: string) => void;
}) {
  const [reason, setReason] = useState(""),
    [provider, setProvider] = useState("mock"),
    [workflow, setWorkflow] = useState("quality"),
    [busy, setBusy] = useState(false);
  const own = item.owner_id === state.user_id,
    editable = ["DRAFT", "NEEDS_CLARIFICATION"].includes(item.status);
  async function act(operation: string, extra = {}) {
    setBusy(true);
    try {
      await command(operation, {
        id: item.id,
        revision: item.revision,
        reason,
        ...extra,
      });
    } catch {
    } finally {
      setBusy(false);
    }
  }
  return (
    <article className="studio-card" data-testid={`contribution-${item.id}`}>
      <span className="studio-badge">{item.status.replaceAll("_", " ")}</span>
      <h3>{item.content.text?.slice(0, 100) || "Untitled draft"}</h3>
      <p className="studio-preserve">{item.content.text}</p>
      <small>Revision {item.revision} · Unverified contribution</small>
      <details>
        <summary>Provenance and permissions</summary>
        <p>Source: {item.content.source || "Not supplied"}</p>
        <p>Method: {item.content.method || "Not supplied"}</p>
        <p>
          Counterpart scope: {item.content.counterpart_scope || "Not supplied"}
        </p>
        {Object.entries(consentLabels).map(([key, label]) => (
          <p key={key}>
            {label}:{" "}
            {item.consent[key]
              ? "Contributor permits (pending rights review)"
              : "Not permitted"}
          </p>
        ))}
      </details>
      {state.events
        .filter(
          (event) =>
            event.contribution_id === item.id && event.snapshot.payload?.reason,
        )
        .map((event) => (
          <p key={event.id}>
            <strong>{event.action.replaceAll("_", " ")}:</strong>{" "}
            {event.snapshot.payload?.reason}
          </p>
        ))}
      {own && editable && (
        <div className="studio-actions">
          <button className="secondary" onClick={() => onEdit(item.id)}>
            Resume draft
          </button>
          <button disabled={busy} onClick={() => void act("submit")}>
            Submit for intake
          </button>
        </div>
      )}
      {own && editable && (
        <UploadControl id={item.id} refresh={refresh} message={message} />
      )}
      {state.uploads
        .filter((x) => x.contribution_id === item.id)
        .map((x) => (
          <p key={x.id}>
            {x.mime} · {x.size_bytes} bytes · Quarantined{" "}
            {item.status !== "WITHDRAWN" && (
              <a href={`/api/studio/upload?id=${x.id}`}>Download original</a>
            )}
          </p>
        ))}
      {item.status !== "WITHDRAWN" && (
        <>
          <label>
            Correction, withdrawal or intake decision reason
            <input
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              maxLength={2000}
            />
          </label>
          <div className="studio-actions">
            {own && (
              <button
                className="secondary"
                disabled={busy}
                onClick={() => void act("withdraw")}
              >
                Withdraw contribution
              </button>
            )}
            {own &&
              ["SUBMITTED", "TRIAGED", "ACCEPTED_FOR_RESEARCH_INTAKE"].includes(
                item.status,
              ) && (
                <button
                  className="secondary"
                  disabled={busy || !reason.trim()}
                  onClick={() => void act("correction")}
                >
                  Request correction
                </button>
              )}
            {researcher && ["SUBMITTED", "TRIAGED"].includes(item.status) && (
              <>
                {item.status === "SUBMITTED" ? (
                  <button
                    disabled={busy || !reason.trim()}
                    onClick={() =>
                      void act("transition", { status: "TRIAGED" })
                    }
                  >
                    Mark triaged
                  </button>
                ) : (
                  <button
                    disabled={busy || !reason.trim()}
                    onClick={() =>
                      void act("transition", {
                        status: "ACCEPTED_FOR_RESEARCH_INTAKE",
                      })
                    }
                  >
                    Accept for research intake
                  </button>
                )}
                <button
                  className="secondary"
                  disabled={busy || !reason.trim()}
                  onClick={() =>
                    void act("transition", { status: "NEEDS_CLARIFICATION" })
                  }
                >
                  Request clarification
                </button>
                <button
                  className="secondary"
                  disabled={busy || !reason.trim()}
                  onClick={() => void act("transition", { status: "REJECTED" })}
                >
                  Reject intake
                </button>
              </>
            )}
            {researcher && item.status === "ACCEPTED_FOR_RESEARCH_INTAKE" && (
              <button
                disabled={busy}
                onClick={() => void act("prepare_handoff")}
              >
                Prepare governed handoff
              </button>
            )}
          </div>
        </>
      )}
      {state.handoffs
        .filter((h) => h.contribution_id === item.id)
        .map((h) => (
          <p key={h.id} className="studio-notice">
            {h.state}: source registration and qualified reviewer integration
            are pending. Canonical and training gates remain closed.
          </p>
        ))}
      {!["WITHDRAWN", "REJECTED"].includes(item.status) && (
        <details>
          <summary>AI research assistance</summary>
          <p>
            Suggestions are machine-generated and unverified. Original content
            is unchanged.
          </p>
          <label>
            Provider
            <select
              value={provider}
              onChange={(e) => setProvider(e.target.value)}
            >
              <option value="mock">Deterministic synthetic assistant</option>
              <option value="openai">
                OpenAI (requires authorization and configuration)
              </option>
            </select>
          </label>
          <label>
            Assistance task
            <select
              value={workflow}
              onChange={(e) => setWorkflow(e.target.value)}
            >
              {[
                "document",
                "vocabulary",
                "quality",
                "clarification",
                "completeness",
                "audio",
              ].map((w) => (
                <option key={w}>{w}</option>
              ))}
            </select>
          </label>
          <button
            disabled={busy}
            onClick={async () => {
              setBusy(true);
              try {
                const response = await fetch("/api/studio/assist", {
                  method: "POST",
                  headers: { "Content-Type": "application/json" },
                  body: JSON.stringify({
                    id: item.id,
                    workflow,
                    provider,
                    request_id: crypto.randomUUID(),
                  }),
                });
                message(
                  response.ok
                    ? "Unverified assistance recorded."
                    : "Assistance unavailable or not authorized. No original content changed.",
                );
                await refresh();
              } finally {
                setBusy(false);
              }
            }}
          >
            Request assistance
          </button>
        </details>
      )}
      {state.ai_runs
        .filter((r) => r.contribution_id === item.id)
        .map((r) => (
          <aside key={r.id} className="studio-ai">
            <strong>MACHINE_GENERATED · {r.verification}</strong>
            <p>
              {r.provider} / {r.model || "pending"} · {r.state}
            </p>
            {[
              ...(r.result?.observations ?? []),
              ...(r.result?.questions ?? []),
              ...(r.result?.candidates ?? []),
            ].map((s, i) => (
              <p key={i}>{s}</p>
            ))}
            <p>{r.result?.uncertainty ?? r.result?.error}</p>
          </aside>
        ))}
    </article>
  );
}

function UploadControl({
  id,
  refresh,
  message,
}: {
  id: string;
  refresh: () => Promise<void>;
  message: (text: string) => void;
}) {
  const [file, setFile] = useState<File | null>(null),
    [recording, setRecording] = useState(false),
    [busy, setBusy] = useState(false);
  const recorder = useRef<MediaRecorder | null>(null),
    stream = useRef<MediaStream | null>(null);
  useEffect(
    () => () => {
      if (recorder.current?.state === "recording") recorder.current.stop();
      stream.current?.getTracks().forEach((t) => t.stop());
    },
    [],
  );
  async function capture() {
    try {
      if (recording) {
        recorder.current?.stop();
        setRecording(false);
        return;
      }
      if (
        !navigator.mediaDevices ||
        !MediaRecorder.isTypeSupported("audio/webm")
      ) {
        message(
          "Recording is unavailable in this browser. Upload a WAV or WebM file instead.",
        );
        return;
      }
      stream.current = await navigator.mediaDevices.getUserMedia({
        audio: true,
      });
      const r = new MediaRecorder(stream.current, { mimeType: "audio/webm" });
      recorder.current = r;
      const chunks: Blob[] = [];
      let size = 0;
      r.ondataavailable = (e) => {
        chunks.push(e.data);
        size += e.data.size;
        if (size > 5 * 1024 * 1024 && r.state === "recording") r.stop();
      };
      r.onstop = () => {
        stream.current?.getTracks().forEach((t) => t.stop());
        setRecording(false);
        setFile(
          new File(chunks, "synthetic-recording.webm", { type: "audio/webm" }),
        );
      };
      r.start(1000);
      setRecording(true);
    } catch {
      message(
        "Microphone access failed. You can upload an existing recording.",
      );
    }
  }
  return (
    <fieldset>
      <legend>Private document or audio · up to 5 MB</legend>
      <label>
        Upload original file
        <input
          type="file"
          accept=".txt,.pdf,.wav,.webm"
          onChange={(e) => setFile(e.target.files?.[0] ?? null)}
        />
      </label>
      <button
        type="button"
        className="secondary"
        onClick={() => void capture()}
      >
        {recording ? "Stop recording" : "Record audio"}
      </button>
      {file && (
        <p>
          {file.name} · {file.size} bytes
        </p>
      )}
      <button
        disabled={!file || busy || recording}
        onClick={async () => {
          if (!file) return;
          setBusy(true);
          const form = new FormData();
          form.set("id", id);
          form.set("file", file);
          form.set("request_id", crypto.randomUUID());
          try {
            const response = await fetch("/api/studio/upload", {
              method: "POST",
              body: form,
            });
            message(
              response.ok
                ? "Original file stored privately in quarantine."
                : "Upload failed. Check file format, size and access; retry with the original file.",
            );
            await refresh();
          } finally {
            setBusy(false);
          }
        }}
      >
        Upload to private quarantine
      </button>
      <small>
        Files are unreviewed. Do not upload authentic research material in this
        synthetic environment.
      </small>
    </fieldset>
  );
}
