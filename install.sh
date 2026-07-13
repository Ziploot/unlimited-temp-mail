#!/bin/bash
# ZipLoot Private Serverless Temp Mail Installer
# ==============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0;37m' # No Color

clear
echo -e "${CYAN}==============================================${NC}"
echo -e "${CYAN}   ⚡ ZIPLOOT PRIVATE TEMP MAIL CONFIGURATOR${NC}"
echo -e "${CYAN}==============================================${NC}"
echo -e "${GREEN}   Serverless | Cloudflare Workers | Vercel | \$0${NC}"
echo -e "${CYAN}==============================================${NC}"
echo

# 1. Check Cloudflare Login
echo -e "${BLUE}[INFO] Checking Cloudflare authentication status...${NC}"
whoami=$(npx -y wrangler whoami 2>&1)
if [[ "$whoami" == *"Not logged in"* || "$whoami" == *"Authentication Error"* || $? -ne 0 ]]; then
    echo -e "${YELLOW}[WARN] You are not logged in to Cloudflare.${NC}"
    echo -e "${YELLOW}Opening login page. Please authorize Wrangler in your browser...${NC}"
    npx -y wrangler login
else
    echo -e "${GREEN}[SUCCESS] Authenticated to Cloudflare!${NC}"
fi
echo

# 2. Create KV Namespace
echo -e "${BLUE}[INFO] Creating Cloudflare KV Namespace...${NC}"
kvOutput=$(npx -y wrangler kv:namespace create TEMP_MAIL_KV 2>&1)
echo "$kvOutput"

kvId=$(echo "$kvOutput" | grep -oE 'id\s*=\s*"[a-f0-9]{32}"' | head -n 1 | cut -d'"' -f2)
if [ -z "$kvId" ]; then
    kvId=$(echo "$kvOutput" | grep -oE 'id":\s*"[a-f0-9]{32}"' | head -n 1 | cut -d'"' -f2)
fi

if [ -z "$kvId" ]; then
    echo -e "${RED}[ERROR] Failed to extract KV Namespace ID.${NC}"
    echo -e "${YELLOW}Please create the KV namespace manually and update wrangler.json.${NC}"
else
    echo -e "${GREEN}[SUCCESS] KV Namespace Created! ID: $kvId${NC}"
    
    # Update wrangler.json with KV ID using temporary Python helper (jq independent)
    python3 -c "
import json
with open('wrangler.json', 'r') as f:
    data = json.load(f)
data['kv_namespaces'][0]['id'] = '$kvId'
with open('wrangler.json', 'w') as f:
    json.dump(data, f, indent=2)
"
    
    # 3. Prompt for Options
    echo
    echo -e "${CYAN}==============================================${NC}"
    echo -e "${GREEN}⚡ Optional Settings Configuration${NC}"
    echo -e "${CYAN}==============================================${NC}"
    
    read -p "Forward copy of all incoming emails to a Gmail/Real Address? (Leave blank to disable): " fwdEmail
    read -p "Custom expiration time for emails in seconds? (Default: 3600 / 1 hour): " ttl
    
    python3 -c "
import json
with open('wrangler.json', 'r') as f:
    data = json.load(f)
if '$fwdEmail' or '$ttl':
    data['vars'] = {}
    if '$fwdEmail':
        data['vars']['FORWARD_EMAIL'] = '$fwdEmail'
    if '$ttl':
        data['vars']['EMAIL_TTL'] = '$ttl'
with open('wrangler.json', 'w') as f:
    json.dump(data, f, indent=2)
"
    echo -e "${GREEN}[SUCCESS] wrangler.json updated successfully!${NC}"
fi
echo

# 4. Install dependencies and deploy worker
echo -e "${BLUE}[INFO] Installing dependencies...${NC}"
npm install

echo -e "${BLUE}[INFO] Deploying Worker to Cloudflare...${NC}"
deployOutput=$(npx -y wrangler deploy 2>&1)
echo "$deployOutput"

workerUrl=$(echo "$deployOutput" | grep -oE 'https://unlimited-temp-mail\.[a-zA-Z0-9-]+\.workers\.dev' | head -n 1)
if [ ! -z "$workerUrl" ]; then
    echo -e "${GREEN}[SUCCESS] Worker deployed successfully!${NC}"
    echo -e "${YELLOW}Worker URL: $workerUrl${NC}"
fi
echo

# 5. Cloudflare Email Routing instructions
echo -e "${CYAN}==============================================${NC}"
echo -e "${GREEN}⚡ CLOUDFLARE EMAIL ROUTING SETUP${NC}"
echo -e "${CYAN}==============================================${NC}"
echo "To link your custom domain to this worker:"
echo "1. Go to Cloudflare Dashboard > [Your Domain] > Email Routing."
echo "2. Enable Email Routing."
echo "3. In 'Routes' > 'Catch-all address' > Click Edit."
echo "4. Action: Send to Worker."
echo "5. Destination: Select 'unlimited-temp-mail'."
echo "6. Click Save. Now all emails sent to your domain route to your Worker!"
echo

# 6. Vercel deployment instructions
echo -e "${CYAN}==============================================${NC}"
echo -e "${GREEN}⚡ DEPLOY CLIENT DASHBOARD TO VERCEL${NC}"
echo -e "${CYAN}==============================================${NC}"
echo "To host the beautiful client web dashboard for free:"
echo "1. Create a free account on Vercel."
echo "2. Install Vercel CLI locally (npm install -g vercel) or import to GitHub."
echo "3. In this project folder, run command:"
echo -e "   ${YELLOW}vercel --prod${NC}"
echo "4. Open the deployed Vercel URL, click 'Setup Config' and enter your Worker URL!"
echo

read -p "Setup complete. Press Enter to exit..."
