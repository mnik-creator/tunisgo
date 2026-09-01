export default async function (req: Request): Promise<Response> {
  // Only allow DELETE or POST
  if (req.method !== "DELETE" && req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Extract user JWT from Authorization header
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  const userToken = authHeader.substring(7);

  // Verify the token and get the current user
  let userId: string;
  try {
    const userResp = await fetch(
      `${Deno.env.get("INSFORGE_BASE_URL")}/api/auth/sessions/current`,
      {
        headers: { Authorization: `Bearer ${userToken}` },
      }
    );
    if (!userResp.ok) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }
    const userData = await userResp.json();
    userId = userData.user?.id;
    if (!userId) {
      return new Response(JSON.stringify({ error: "User not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }
  } catch {
    return new Response(JSON.stringify({ error: "Token verification failed" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Delete the user using admin API key
  const adminApiKey = Deno.env.get("API_KEY");
  if (!adminApiKey) {
    return new Response(JSON.stringify({ error: "Server configuration error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const deleteResp = await fetch(
    `${Deno.env.get("INSFORGE_BASE_URL")}/api/auth/users`,
    {
      method: "DELETE",
      headers: {
        Authorization: `Bearer ${adminApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ userIds: [userId] }),
    }
  );

  if (!deleteResp.ok) {
    const errBody = await deleteResp.text();
    return new Response(
      JSON.stringify({ error: "Failed to delete account", details: errBody }),
      {
        status: deleteResp.status,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}
