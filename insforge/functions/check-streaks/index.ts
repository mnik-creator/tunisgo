// Daily cron job: find all users with a 15-day consecutive streak and
// grant them a 30-day "TunisGO pro" entitlement via the RevenueCat API.
//
// This function is intended to be called by a scheduled InsForge cron job
// (no user auth required — secured by the API_KEY in the Authorization header).
//
// RevenueCat v1 promotional entitlement endpoint:
//   POST /v1/subscribers/{app_user_id}/entitlements/{entitlement_id}/promotional
//   Authorization: Bearer <REVENUECAT_SECRET_KEY>
//   Body: { "duration": "monthly" }   ← ~30 days

const RC_ENTITLEMENT = "TunisGO pro";
const STREAK_THRESHOLD = 15;

export default async function (req: Request): Promise<Response> {
  // This endpoint is cron-only (no browser callers) — OPTIONS not needed.

  // ── Verify caller is authorised (must send the InsForge API key) ──────────
  const authHeader = req.headers.get("Authorization");
  const apiKey = Deno.env.get("API_KEY")!;
  if (authHeader !== `Bearer ${apiKey}`) {
    return json({ error: "Forbidden" }, 403);
  }

  const base = Deno.env.get("INSFORGE_BASE_URL")!;
  const rcKey = Deno.env.get("REVENUECAT_SECRET_KEY");
  if (!rcKey) {
    return json({ error: "REVENUECAT_SECRET_KEY secret not configured" }, 500);
  }

  // ── Fetch all users who have an activity row for each of the last 15 days ─
  // Strategy: pull activity_date >= today-14 grouped by user_id, keep those
  // with 15 distinct dates (each of the last 15 consecutive days).
  const since = utcDateMinus(STREAK_THRESHOLD - 1); // 14 days ago

  const actRes = await fetch(
    `${base}/rest/v1/user_activity?activity_date=gte.${since}&select=user_id,activity_date&order=user_id,activity_date.desc`,
    {
      headers: {
        apikey: apiKey,
        Authorization: `Bearer ${apiKey}`,
      },
    },
  );
  if (!actRes.ok) {
    return json({ error: "Failed to query user_activity" }, 502);
  }
  const rows: { user_id: string; activity_date: string }[] =
    await actRes.json();

  // Group by user, check if they have all 15 required dates
  const userDates = new Map<string, Set<string>>();
  for (const row of rows) {
    if (!userDates.has(row.user_id)) userDates.set(row.user_id, new Set());
    userDates.get(row.user_id)!.add(row.activity_date);
  }

  const qualifyingUsers: string[] = [];
  for (const [userId, dates] of userDates) {
    if (hasConsecutiveStreak(dates, STREAK_THRESHOLD)) {
      qualifyingUsers.push(userId);
    }
  }

  // ── Grant 30-day entitlement via RevenueCat for each qualifying user ──────
  const results: { userId: string; status: string }[] = [];

  for (const userId of qualifyingUsers) {
    try {
      const rcRes = await fetch(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}/entitlements/${encodeURIComponent(RC_ENTITLEMENT)}/promotional`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${rcKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ duration: "monthly" }), // ~30 days
        },
      );

      if (rcRes.ok) {
        // Update profiles table with new subscription info
        const expiration = new Date();
        expiration.setUTCDate(expiration.getUTCDate() + 30);

        await fetch(`${base}/rest/v1/profiles?id=eq.${userId}`, {
          method: "PATCH",
          headers: {
            apikey: apiKey,
            Authorization: `Bearer ${apiKey}`,
            "Content-Type": "application/json",
            Prefer: "return=minimal",
          },
          body: JSON.stringify({
            subscription_status: "streak_reward",
            subscription_date: new Date().toISOString(),
            subscription_expiration: expiration.toISOString(),
          }),
        });

        results.push({ userId, status: "granted" });
      } else {
        const errText = await rcRes.text();
        results.push({ userId, status: `rc_error_${rcRes.status}: ${errText}` });
      }
    } catch (err) {
      results.push({ userId, status: `error: ${err}` });
    }
  }

  return json({
    checked: userDates.size,
    qualified: qualifyingUsers.length,
    results,
  });
}

/** Returns true if [dates] contains all STREAK_THRESHOLD consecutive days ending today. */
function hasConsecutiveStreak(dates: Set<string>, threshold: number): boolean {
  for (let i = 0; i < threshold; i++) {
    if (!dates.has(utcDateMinus(i))) return false;
  }
  return true;
}

function utcDateMinus(days: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - days);
  return d.toISOString().slice(0, 10);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
