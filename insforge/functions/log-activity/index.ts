// Log a daily app-open for the authenticated user.
// Upserts a row into user_activity for today (UNIQUE constraint ignores duplicates).
// Returns: { logged: boolean, streak: number }

export default async function (req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // ── Authenticate ─────────────────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return json({ error: "Missing Authorization header" }, 401);
  }
  const userToken = authHeader.slice(7);

  const base = Deno.env.get("INSFORGE_BASE_URL")!;
  const apiKey = Deno.env.get("API_KEY")!;

  const userRes = await fetch(`${base}/api/auth/sessions/current`, {
    headers: { Authorization: `Bearer ${userToken}` },
  });
  if (!userRes.ok) return json({ error: "Invalid token" }, 401);

  const { user } = await userRes.json();
  const userId: string = user?.id;
  if (!userId) return json({ error: "User not found" }, 404);

  // ── Upsert today's activity ──────────────────────────────────────────────
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD

  const upsertRes = await fetch(`${base}/rest/v1/user_activity`, {
    method: "POST",
    headers: {
      apikey: apiKey,
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      Prefer: "resolution=ignore-duplicates,return=minimal",
    },
    body: JSON.stringify({ user_id: userId, activity_date: today }),
  });

  // 201 = inserted (first open today), 200 = ignored duplicate
  const logged = upsertRes.status === 201;

  // ── Compute current consecutive-day streak ───────────────────────────────
  const streak = await computeStreak(base, apiKey, userId);

  return json({ logged, streak });
}

async function computeStreak(
  base: string,
  apiKey: string,
  userId: string,
): Promise<number> {
  const res = await fetch(
    `${base}/rest/v1/user_activity?user_id=eq.${userId}&select=activity_date&order=activity_date.desc&limit=60`,
    {
      headers: {
        apikey: apiKey,
        Authorization: `Bearer ${apiKey}`,
      },
    },
  );
  if (!res.ok) return 0;

  const rows: { activity_date: string }[] = await res.json();
  if (rows.length === 0) return 0;

  let streak = 0;
  for (let i = 0; i < rows.length; i++) {
    const expected = utcDateMinus(i);
    if (rows[i].activity_date === expected) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

/** Returns YYYY-MM-DD for UTC today minus [days]. */
function utcDateMinus(days: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - days);
  return d.toISOString().slice(0, 10);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}

function corsHeaders(): Record<string, string> {
  // Called only from the native mobile app — no browser origin is valid.
  // Restrict to prevent cross-site request forgery from any future web client.
  return {
    "Access-Control-Allow-Origin": "https://tunisgo.app",
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}
