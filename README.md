# QuietStay

Digital guidebooks that answer guests before they message you — a done-for-you guidebook + matching printed manual for short-term rental hosts. Built for the offer2stay host base.

**Stack:** Next.js (App Router) · Supabase (Postgres + RLS + PostGIS) · Vercel.

## Run locally

```bash
npm install
cp .env.local.example .env.local   # values are already filled for the QuietStay Supabase project
npm run dev                         # http://localhost:3000
```

## Environment variables

Set these in `.env.local` (local) and in Vercel → Project → Settings → Environment Variables:

| Key | Value |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | `https://ppigflebiswduvxuogut.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `sb_publishable_gj3BUVSgMrO3aEcjSb4QSQ_NCGm5WKP` |
| `SUPABASE_SERVICE_ROLE_KEY` | *(server only — from Supabase dashboard, do not commit)* |

## Routes

- `/` — landing.
- `/g/[slug]` — public guest guidebook (reads a published guidebook by slug via Supabase RLS).

## Database

Schema lives in `supabase/migrations/`. It is already applied to the live project
`ppigflebiswduvxuogut`. Multi-tenant with Row-Level Security, plus PostGIS for
proximity-based local recommendations.

## Roadmap

Owner quick-edit · host intake questionnaire (auto-import) · internal service console
(`service_jobs` pipeline) · per-area recommendation libraries (Newcastle, Northumberland
sub-areas) · listing auto-parse · print book PDF pipeline · Stripe (first month free).
