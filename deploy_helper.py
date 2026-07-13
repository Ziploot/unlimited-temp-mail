import subprocess
import json
import re
import os
import sys

# Ensure stdout uses UTF-8 to prevent console encoding crashes on Windows
sys.stdout.reconfigure(encoding='utf-8') if hasattr(sys.stdout, 'reconfigure') else None

def run_command(cmd_str, capture=True):
    # Run a shell command in the current folder, using custom environment to bypass junction errors
    env = os.environ.copy()
    env["USERPROFILE"] = "C:\\Users\\user\\AppData\\Local"
    env["HOMEPATH"] = "\\Users\\user\\AppData\\Local"
    env["HOME"] = "C:\\Users\\user\\AppData\\Local"
    
    try:
        if capture:
            res = subprocess.run(
                cmd_str,
                env=env,
                capture_output=True,
                shell=True
            )
            # Safe UTF-8 decoding ignoring errors
            res.stdout = res.stdout.decode('utf-8', errors='ignore') if res.stdout else ""
            res.stderr = res.stderr.decode('utf-8', errors='ignore') if res.stderr else ""
        else:
            res = subprocess.run(
                cmd_str,
                env=env,
                shell=True
            )
            # Add dummy attributes for compatibility
            res.stdout = ""
            res.stderr = ""
            
        return res
    except Exception as e:
        print(f"[ERROR] Failed to execute command: {cmd_str}")
        print(str(e))
        return None

def main():
    print("==============================================")
    print("   ZIPLOOT PRIVATE TEMP MAIL CONFIGURATOR")
    print("==============================================")
    print("   Serverless | Cloudflare Workers & Pages | Free")
    print("==============================================")
    print()

    # 1. Check Cloudflare Login
    print("[INFO] Checking Cloudflare authentication status...")
    whoami = run_command("npx wrangler whoami")
    if not whoami or "Not logged in" in whoami.stdout or "Authentication Error" in whoami.stdout or whoami.returncode != 0:
        print("[WARN] You are not logged in to Cloudflare.")
        print("Opening login page. Please authorize Wrangler in your browser...")
        run_command("npx wrangler login", capture=False)
    else:
        print("[SUCCESS] Authenticated to Cloudflare!")
    print()

    # 2. Create KV Namespace
    print("[INFO] Creating Cloudflare KV Namespace...")
    kv_create = run_command("npx wrangler kv:namespace create TEMP_MAIL_KV")
    if not kv_create or kv_create.returncode != 0:
        print("[ERROR] Failed to create KV Namespace. Details:")
        if kv_create:
            print(kv_create.stderr or kv_create.stdout)
        print("Please create the KV namespace manually and update wrangler.json.")
        sys.exit(1)
        
    output_str = kv_create.stdout + "\n" + kv_create.stderr
    kv_id = ""
    # Extract KV ID using regex
    match = re.search(r'id\s*=\s*"([a-f0-9]{32})"', output_str)
    if not match:
        match = re.search(r'id":\s*"([a-f0-9]{32})"', output_str)
    
    if match:
        kv_id = match.group(1)
        print(f"[SUCCESS] KV Namespace Created! ID: {kv_id}")
    else:
        print("[ERROR] Could not extract KV ID from output. Output was:")
        print(output_str)
        sys.exit(1)
        
    # Update wrangler.json with KV ID
    if os.path.exists("wrangler.json"):
        with open("wrangler.json", "r", encoding="utf-8") as f:
            config = json.load(f)
        
        config["kv_namespaces"][0]["id"] = kv_id
        
        # 3. Prompt for Options
        print()
        print("==============================================")
        print("⚡ Settings Configuration")
        print("==============================================")
        
        fwd_email = input("[INPUT] Forward copy of all incoming emails to a Gmail/Real Address? (Leave blank to disable): ").strip()
        ttl = input("[INPUT] Custom expiration time for emails in seconds? (Default: 3600 / 1 hour): ").strip()
        
        if fwd_email or ttl:
            config["vars"] = {}
            if fwd_email:
                config["vars"]["FORWARD_EMAIL"] = fwd_email
                print(f"[OK] Enabled forwarding to {fwd_email}")
            if ttl:
                config["vars"]["EMAIL_TTL"] = ttl
                print(f"[OK] Expire time set to {ttl} seconds")
                
        with open("wrangler.json", "w", encoding="utf-8") as f:
            json.dump(config, f, indent=2)
        print("[SUCCESS] wrangler.json updated successfully!")
    print()

    # 4. Install dependencies and deploy worker
    print("[INFO] Installing dependencies...")
    run_command("npm install", capture=False)
    print()

    print("[INFO] Deploying Worker to Cloudflare...")
    deploy = run_command("npx wrangler deploy")
    if not deploy or deploy.returncode != 0:
        print("[ERROR] Failed to deploy Worker. Details:")
        if deploy:
            print(deploy.stderr or deploy.stdout)
        sys.exit(1)
        
    deploy_str = deploy.stdout + "\n" + deploy.stderr
    worker_url = ""
    # Extract worker URL using regex
    url_match = re.search(r'https://unlimited-temp-mail\.[a-zA-Z0-9-]+\.workers\.dev', deploy_str)
    if url_match:
        worker_url = url_match.group(0)
        print(f"[SUCCESS] Worker deployed successfully! URL: {worker_url}")
    else:
        print("[WARN] Could not automatically extract Worker URL. Please check deployment logs.")
        print(deploy_str)
    print()

    # 5. Inject Worker URL into public/index.html
    if worker_url and os.path.exists("public/index.html"):
        with open("public/index.html", "r", encoding="utf-8") as f:
            html = f.read()
            
        target = 'let workerApiUrl = localStorage.getItem("temp_mail_worker_url") || "";'
        replacement = f'let workerApiUrl = localStorage.getItem("temp_mail_worker_url") || "{worker_url}";'
        html = html.replace(target, replacement)
        
        with open("public/index.html", "w", encoding="utf-8") as f:
            f.write(html)
        print("[SUCCESS] Worker URL injected into Web Client config!")
    print()

    # 6. Deploy Pages
    print("[INFO] Deploying Web Client to Cloudflare Pages...")
    # Create project if not exists
    run_command("npx wrangler pages project create unlimited-temp-mail --production-branch main")
    # Deploy public folder
    pages = run_command("npx wrangler pages deploy public --project-name unlimited-temp-mail")
    
    pages_str = pages.stdout + "\n" + pages.stderr if pages else ""
    pages_url = ""
    pages_match = re.search(r'https://[a-zA-Z0-9-.]*unlimited-temp-mail\.pages\.dev', pages_str)
    if pages_match:
        pages_url = pages_match.group(0)
        print(f"[SUCCESS] Web Dashboard deployed successfully! URL: {pages_url}")
    else:
        print("[WARN] Could not extract Pages URL.")
        print(pages_str)
    print()

    # 7. Cloudflare Email Routing instructions
    print("==============================================")
    print("⚡ CLOUDFLARE EMAIL ROUTING SETUP")
    print("==============================================")
    print("To link your custom domain to this worker:")
    print("1. Go to Cloudflare Dashboard > [Your Domain] > Email Routing.")
    print("2. Enable Email Routing.")
    print("3. In 'Routes' > 'Catch-all address' > Click Edit.")
    print("4. Action: Send to Worker.")
    print("5. Destination: Select 'unlimited-temp-mail'.")
    print("6. Click Save. Now all emails sent to your domain route to your Worker!")
    print()

    print("==============================================")
    print("🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!")
    print("==============================================")
    if pages_url:
        print(f"🔗 Web Dashboard: {pages_url}")
    if worker_url:
        print(f"⚙️ Worker API: {worker_url}")
    print("==============================================")
    print()
    input("Setup complete. Press Enter to exit...")

if __name__ == "__main__":
    main()
