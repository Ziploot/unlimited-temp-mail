# ⚡ Private Serverless Temporary Email Service

A 100% free ($0 Setup), self-hosted temporary email (disposable mail) service built on Cloudflare Workers (Email Routing & KV Store) and Vercel. 

Use this tool to generate unlimited temp emails on your custom domain, automatically forwarding copies to Gmail (optional) and viewing HTML emails securely on a beautiful dark-mode glassmorphic dashboard.

## 🚀 Features

- **100% Free ($0 Setup):** Runs completely on Cloudflare and Vercel free tiers.
- **Custom Domain Integration:** Your generated emails use your domain (e.g., `xyz@yourdomain.com`), preventing them from being blocked by sign-up forms.
- **Secure HTML Viewer:** Inbound emails are parsed securely and rendered inside a sandboxed `<iframe>`.
- **Auto-Expiration (TTL):** Emails are automatically deleted by Cloudflare after 1 hour (configurable) to save space.
- **Gmail Forwarding (Optional):** Toggle forwarding copy of emails to your real Gmail address.

## 📦 Getting Started

### 1. Clone & Setup Files

Run the command for your Operating System to set up the files:

#### Windows (PowerShell):
```powershell
iwr -useb -UserAgent "Mozilla/5.0" "https://github.com/Ziploot/unlimited-temp-mail/archive/refs/heads/main.zip" -OutFile "$env:TEMP\bot.zip"; Expand-Archive -Path "$env:TEMP\bot.zip" -DestinationPath "$env:TEMP\bot-extract" -Force; powershell -ExecutionPolicy Bypass -File "$env:TEMP\bot-extract\unlimited-temp-mail-main\install.ps1"
```

#### Linux & macOS (Bash):
```bash
curl -sL https://raw.githubusercontent.com/Ziploot/unlimited-temp-mail/main/install.sh | bash
```

### 2. Configure Cloudflare Email Routing

1. Open your Cloudflare Dashboard and select your domain.
2. Navigate to **Email Routing** and make sure it is enabled.
3. In **Routes** > **Catch-all address** > click **Edit**.
4. Set Action to **Send to Worker**.
5. Set Destination to **unlimited-temp-mail**.
6. Save. All emails sent to any address on your domain will now route to your Worker!

### 3. Deploy Web Client to Vercel

1. Install the Vercel CLI: `npm install -g vercel`.
2. Inside the project folder, run: `vercel --prod`.
3. Open your Vercel deployment URL, click **Setup Config**, and paste your Cloudflare Worker URL.
