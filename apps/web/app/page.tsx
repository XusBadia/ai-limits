const providers = [
  { name: "Codex", detail: "5-hour + weekly limits", tone: "codex" },
  { name: "Claude", detail: "Session + weekly limits", tone: "claude" },
];

const sourceURL = "https://github.com/xusbadia/ai-limits";
const collectorURL = `${sourceURL}/releases/download/v0.1.0/AI-Limits-Collector-0.1.0.zip`;

function Mark({ compact = false }: { compact?: boolean }) {
  return (
    <span className={compact ? "mark mark--compact" : "mark"} aria-hidden="true">
      <span />
      <span />
      <span />
    </span>
  );
}

function Arrow() {
  return (
    <svg viewBox="0 0 20 20" aria-hidden="true">
      <path d="M4 10h11M11 5l5 5-5 5" />
    </svg>
  );
}

function UsageRow({ label, used, reset }: { label: string; used: number; reset: string }) {
  return (
    <div className="usage-row">
      <div className="usage-label">
        <span>{label}</span>
        <strong>{used}% used</strong>
      </div>
      <div className="meter" aria-label={`${label}: ${used}% used`}>
        <span style={{ width: `${used}%` }} />
      </div>
      <small>Resets {reset}</small>
    </div>
  );
}

function ProviderCard({ name, plan, tone, rows }: {
  name: string;
  plan: string;
  tone: string;
  rows: Array<{ label: string; used: number; reset: string }>;
}) {
  return (
    <article className={`provider-card provider-card--${tone}`}>
      <header>
        <span className="provider-dot" />
        <strong>{name}</strong>
        <span className="plan">{plan}</span>
        <span className="card-arrow">›</span>
      </header>
      {rows.map((row) => <UsageRow key={row.label} {...row} />)}
    </article>
  );
}

export default function Home() {
  return (
    <main>
      <nav className="nav wrap" aria-label="Main navigation">
        <a className="brand" href="#top" aria-label="AI Limits home"><Mark compact />AI Limits</a>
        <div className="nav-links">
          <a href="#privacy">Privacy</a>
          <a href="#providers">Providers</a>
          <a href={sourceURL}>Source</a>
        </div>
        <a className="nav-cta" href="#availability">Get the beta</a>
      </nav>

      <section className="hero wrap" id="top">
        <div className="hero-copy">
          <p className="eyebrow"><span /> One glance. No surprises.</p>
          <h1>Know what you can still ask AI today.</h1>
          <p className="hero-lede">
            AI Limits puts your Codex and Claude usage in one calm iPhone dashboard —
            before a quota interrupts your work.
          </p>
          <div className="hero-actions">
            <a className="button button--primary" href="#availability">Join the TestFlight <Arrow /></a>
            <a className="button button--quiet" href="#how-it-works">See how it works</a>
          </div>
          <p className="privacy-note"><span>✓</span> Credentials never leave your Mac.</p>
        </div>

        <div className="product-stage" aria-label="Preview of the AI Limits iPhone dashboard">
          <div className="orbit orbit--one" />
          <div className="orbit orbit--two" />
          <div className="phone">
            <div className="phone-bar"><span>9:41</span><span className="island" /><span>● ●●</span></div>
            <div className="phone-content">
              <div className="app-heading">
                <p>Your AI capacity</p>
                <span>now</span>
                <small>Before it runs out</small>
              </div>
              <ProviderCard
                name="Claude"
                plan="MAX"
                tone="claude"
                rows={[
                  { label: "Session", used: 72, reset: "54 min" },
                  { label: "Weekly", used: 41, reset: "4 days" },
                ]}
              />
              <ProviderCard
                name="Codex"
                plan="PRO"
                tone="codex"
                rows={[
                  { label: "5-hour", used: 38, reset: "2 hr" },
                  { label: "Weekly", used: 64, reset: "3 days" },
                ]}
              />
              <div className="phone-privacy">♢ &nbsp; Credentials stay on your Mac</div>
            </div>
          </div>
          <div className="floating-chip floating-chip--top"><span className="pulse" /> Updated just now</div>
          <div className="floating-chip floating-chip--bottom">Private iCloud sync&nbsp; ✓</div>
        </div>
      </section>

      <section className="provider-strip" id="providers" aria-label="Supported providers">
        <div className="wrap provider-strip-inner">
          <p>Works with the tools you already use</p>
          <div className="provider-list">
            {providers.map((provider) => (
              <div key={provider.name} className={`provider-pill provider-pill--${provider.tone}`}>
                <span /> <strong>{provider.name}</strong> <small>{provider.detail}</small>
              </div>
            ))}
          </div>
          <span className="coming">More providers next</span>
        </div>
      </section>

      <section className="steps wrap" id="how-it-works">
        <div className="section-intro">
          <p className="eyebrow"><span /> Tiny utility, useful every day</p>
          <h2>Set it once.<br />Check it anywhere.</h2>
        </div>
        <div className="step-grid">
          <article><b>01</b><h3>Open the Mac collector</h3><p>It reads usage from the AI tools already signed in on your Mac.</p></article>
          <article><b>02</b><h3>Sync through your iCloud</h3><p>Only normalized usage numbers cross devices — never your API keys or session tokens.</p></article>
          <article><b>03</b><h3>Glance before you start</h3><p>See the tightest limit first on iPhone or in a home-screen widget.</p></article>
        </div>
      </section>

      <section className="privacy-section" id="privacy">
        <div className="wrap privacy-grid">
          <div>
            <p className="eyebrow eyebrow--light"><span /> Built private by default</p>
            <h2>Your keys stay home.<br />Only the numbers travel.</h2>
            <p className="privacy-copy">The collector runs locally. Snapshots are stored in your private CloudKit database, protected by your Apple Account.</p>
            <a className="text-link" href={`${sourceURL}/blob/main/docs/privacy-and-security.md`}>Read the security design <Arrow /></a>
          </div>
          <div className="privacy-flow" aria-label="Privacy architecture: Mac collector to private iCloud to iPhone">
            <article><span className="device-icon">⌘</span><div><strong>Your Mac</strong><small>Reads local sessions</small></div></article>
            <i><span>usage only</span></i>
            <article><span className="device-icon">☁</span><div><strong>Private iCloud</strong><small>Encrypted snapshot</small></div></article>
            <i><span>your account</span></i>
            <article><span className="device-icon">▯</span><div><strong>Your iPhone</strong><small>Dashboard + widget</small></div></article>
          </div>
        </div>
      </section>

      <section className="open-source wrap">
        <div className="oss-card">
          <div><Mark /><p>Open source from the first commit.</p></div>
          <h2>Trust is easier<br />when the code is visible.</h2>
          <p>Inspect every collector, verify what syncs, or help add the next provider. AI Limits is built in public.</p>
          <a className="button button--outline" href={sourceURL}>Explore on GitHub <Arrow /></a>
        </div>
        <div className="faq">
          <h2>Good questions.</h2>
          <details><summary>Does AI Limits need my API keys?<span>+</span></summary><p>No. The Mac companion reads usage from supported clients already authenticated on your computer.</p></details>
          <details><summary>Does the iPhone fetch usage directly?<span>+</span></summary><p>No. Apple&apos;s sandbox prevents that. The local Mac collector publishes a minimal snapshot to your private iCloud database.</p></details>
          <details><summary>Which AI tools work today?<span>+</span></summary><p>The first beta supports Codex and Claude. The collector architecture is ready for more providers.</p></details>
          <details><summary>Will it be free?<span>+</span></summary><p>The core project is open source. Beta access and final App Store details will be announced publicly.</p></details>
        </div>
      </section>

      <section className="availability wrap" id="availability">
        <div>
          <p className="eyebrow eyebrow--light"><span /> Private beta</p>
          <h2>Your AI limits,<br />finally in your pocket.</h2>
        </div>
        <div>
          <p>The iPhone beta is live in TestFlight. Pair it with the signed Mac collector to publish usage through your private iCloud account.</p>
          <a className="button button--white" href={collectorURL}>Download for Mac <Arrow /></a>
        </div>
      </section>

      <footer className="wrap">
        <a className="brand" href="#top"><Mark compact />AI Limits</a>
        <p>Built for people who ask a lot of AI.</p>
        <div><a href={`${sourceURL}/blob/main/LICENSE`}>License</a><a href={`${sourceURL}/blob/main/docs/privacy-and-security.md`}>Privacy</a><a href={sourceURL}>GitHub</a></div>
      </footer>
    </main>
  );
}
