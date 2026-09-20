import Image from "next/image";
import type { ReactNode } from "react";

export function AuthShell({ children }: { children: ReactNode }) {
  return <main className="auth-layout">
    <section className="auth-form-panel">
      <div className="auth-form-inner">
        <a className="auth-institute" href="https://www.gdsi.institute/" aria-label="Global Data Science Institute home">
          <Image src="/gdsi-logo.svg" alt="Global Data Science Institute" width={250} height={52} priority />
        </a>
        <p className="auth-project">Project Tafsiri</p>
        <p className="auth-portal">Language Reviewer Portal</p>
        {children}
        <a className="auth-return" href="https://www.gdsi.institute/">Return to GDSI</a>
      </div>
    </section>
    <aside className="auth-visual" aria-label="Project Tafsiri research identity">
      <div className="auth-visual-content">
        <p className="auth-visual-kicker">Global Data Science Institute · Language research</p>
        <div className="auth-orbit" aria-hidden="true"><span /><span /><span /></div>
        <p className="auth-visual-statement">Preserving language.<br />Building technology.<br />Connecting knowledge.</p>
        <p className="auth-visual-caption">Independent human review strengthens dialect-aware resources.</p>
      </div>
    </aside>
  </main>;
}
