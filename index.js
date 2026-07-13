import PostalMime from 'postal-mime';

export default {
  async email(message, env, ctx) {
    try {
      // 1. Forward the email to a secondary backup address if configured
      if (env.FORWARD_EMAIL) {
        try {
          await message.forward(env.FORWARD_EMAIL);
        } catch (fwdErr) {
          console.error("Failed to forward email to target:", env.FORWARD_EMAIL, fwdErr);
        }
      }

      // 2. Parse the raw email content
      const rawEmail = await new Response(message.raw).arrayBuffer();
      const parser = new PostalMime();
      const email = await parser.parse(rawEmail);

      const recipient = message.to.toLowerCase().trim();
      const sender = message.from;
      const subject = email.subject || "(No Subject)";
      const date = email.date || new Date().toISOString();
      const text = email.text || "";
      const html = email.html || "";
      
      const attachments = (email.attachments || []).map(att => ({
        filename: att.filename,
        mimeType: att.mimeType,
        size: att.content ? att.content.byteLength : 0
      }));

      const emailData = {
        id: crypto.randomUUID(),
        from: sender,
        to: recipient,
        subject: subject,
        date: date,
        text: text,
        html: html,
        attachments: attachments
      };

      // 3. Save to Cloudflare KV with expiration (TTL)
      const timestamp = Date.now();
      const kvKey = `email:${recipient}:${timestamp}:${emailData.id}`;
      
      const ttl = parseInt(env.EMAIL_TTL || "3600"); // 1 hour default
      await env.TEMP_MAIL_KV.put(kvKey, JSON.stringify(emailData), {
        expirationTtl: ttl
      });

      console.log(`Saved email to KV: ${kvKey}`);
    } catch (err) {
      console.error("Error processing incoming email:", err);
    }
  },

  async fetch(request, env) {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS, DELETE",
      "Access-Control-Allow-Headers": "Content-Type",
      "Access-Control-Max-Age": "86400"
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);

    // API: List emails for a recipient
    if (url.pathname === "/api/inbox") {
      const email = url.searchParams.get("email");
      if (!email) {
        return new Response(JSON.stringify({ error: "Missing email parameter" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      const cleanEmail = email.toLowerCase().trim();
      const prefix = `email:${cleanEmail}:`;

      try {
        const listResult = await env.TEMP_MAIL_KV.list({ prefix });
        
        // Fetch values for found keys
        const fetchPromises = listResult.keys.map(async (keyObj) => {
          const val = await env.TEMP_MAIL_KV.get(keyObj.name);
          if (val) {
            const data = JSON.parse(val);
            return {
              key: keyObj.name,
              id: data.id,
              from: data.from,
              subject: data.subject,
              date: data.date,
              hasAttachments: data.attachments && data.attachments.length > 0
            };
          }
          return null;
        });

        const fetched = await Promise.all(fetchPromises);
        const filtered = fetched.filter(item => item !== null);
        
        // Sort descending (newest first)
        filtered.sort((a, b) => new Date(b.date) - new Date(a.date));

        return new Response(JSON.stringify(filtered), {
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      } catch (err) {
        return new Response(JSON.stringify({ error: err.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }
    }

    // API: Fetch single email details
    if (url.pathname === "/api/email") {
      const key = url.searchParams.get("key");
      if (!key) {
        return new Response(JSON.stringify({ error: "Missing key parameter" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      if (request.method === "DELETE") {
        try {
          await env.TEMP_MAIL_KV.delete(key);
          return new Response(JSON.stringify({ success: true }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" }
          });
        } catch (err) {
          return new Response(JSON.stringify({ error: err.message }), {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" }
          });
        }
      }

      try {
        const val = await env.TEMP_MAIL_KV.get(key);
        if (!val) {
          return new Response(JSON.stringify({ error: "Email not found" }), {
            status: 404,
            headers: { ...corsHeaders, "Content-Type": "application/json" }
          });
        }

        return new Response(val, {
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      } catch (err) {
        return new Response(JSON.stringify({ error: err.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }
    }

    return new Response(JSON.stringify({ error: "Endpoint Not Found" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
};
