export default function Home() {
  return (
    <main className="container">
      <div className="hero">
        <h1>QuietStay</h1>
        <p>Digital guidebooks that answer your guests before they message you.</p>
      </div>

      <div className="section">
        <h2>It&apos;s live 🎉</h2>
        <div className="item">
          <p>
            This is the QuietStay app, deployed from GitHub to Vercel and wired to Supabase.
            A guest guidebook lives at <code>/g/&lt;slug&gt;</code> once it&apos;s published.
          </p>
        </div>
      </div>

      <div className="section">
        <h2>What&apos;s next</h2>
        <div className="item"><p>Owner quick-edit · host intake questionnaire · internal service console · per-area recommendation libraries · print book pipeline · Stripe (first month free).</p></div>
      </div>

      <p className="footer">QuietStay · built for offer2stay hosts</p>
    </main>
  );
}
