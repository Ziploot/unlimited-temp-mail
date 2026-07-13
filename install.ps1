# ZipLoot Private Serverless Temp Mail Installer
# ==============================================
try {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "   ⚡ ZIPLOOT PRIVATE TEMP MAIL CONFIGURATOR" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "   Serverless | Cloudflare Workers | Vercel | \$0" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host

    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    if ([string]::IsNullOrEmpty($scriptDir)) { $scriptDir = $pwd }

    # 1. Check Cloudflare Login
    Write-Host "[INFO] Checking Cloudflare authentication status..." -ForegroundColor Blue
    $whoami = npx -y wrangler whoami 2>&1
    if ($whoami -match "Not logged in" -or $whoami -match "Authentication Error" -or $LASTEXITCODE -ne 0) {
        Write-Host "[WARN] You are not logged in to Cloudflare." -ForegroundColor Yellow
        Write-Host "Opening login page. Please authorize Wrangler in your browser..." -ForegroundColor Yellow
        npx -y wrangler login
    } else {
        Write-Host "[SUCCESS] Authenticated to Cloudflare!" -ForegroundColor Green
    }
    Write-Host

    # 2. Create KV Namespace
    Write-Host "[INFO] Creating Cloudflare KV Namespace..." -ForegroundColor Blue
    $kvOutput = npx -y wrangler kv:namespace create TEMP_MAIL_KV 2>&1
    $kvOutputStr = Out-String -InputObject $kvOutput
    
    $kvId = ""
    # Extract KV ID using regex
    if ($kvOutputStr -match 'id\s*=\s*"([a-f0-9]{32})"') {
        $kvId = $Matches[1]
    } elseif ($kvOutputStr -match 'id":\s*"([a-f0-9]{32})"') {
        $kvId = $Matches[1]
    }

    if ([string]::IsNullOrEmpty($kvId)) {
        Write-Host "[ERROR] Failed to extract KV Namespace ID. Output was:" -ForegroundColor Red
        Write-Host $kvOutputStr -ForegroundColor Yellow
        Write-Host "Please create the KV namespace manually and update wrangler.json." -ForegroundColor Yellow
    } else {
        Write-Host "[SUCCESS] KV Namespace Created! ID: $kvId" -ForegroundColor Green
        
        # Update wrangler.json with KV ID
        $wranglerPath = Join-Path $scriptDir "wrangler.json"
        if (Test-Path $wranglerPath) {
            $config = Get-Content $wranglerPath -Raw | ConvertFrom-Json
            $config.kv_namespaces[0].id = $kvId
            
            # 3. Prompt for Options
            Write-Host
            Write-Host "==============================================" -ForegroundColor Cyan
            Write-Host "⚡ Optional Settings Configuration" -ForegroundColor Green
            Write-Host "==============================================" -ForegroundColor Cyan
            
            $fwdEmail = Read-Host "[INPUT] Forward copy of all incoming emails to a Gmail/Real Address? (Leave blank to disable)"
            if (-not [string]::IsNullOrEmpty($fwdEmail)) {
                $config | Add-Member -MemberType NoteProperty -Name "vars" -Value @{ "FORWARD_EMAIL" = $fwdEmail } -Force
                Write-Host "[OK] Enabled forwarding to $fwdEmail" -ForegroundColor Green
            }
            
            $ttl = Read-Host "[INPUT] Custom expiration time for emails in seconds? (Default: 3600 / 1 hour)"
            if (-not [string]::IsNullOrEmpty($ttl)) {
                if ($config.vars) {
                    $config.vars.EMAIL_TTL = $ttl
                } else {
                    $config | Add-Member -MemberType NoteProperty -Name "vars" -Value @{ "EMAIL_TTL" = $ttl } -Force
                }
                Write-Host "[OK] Expire time set to $ttl seconds" -ForegroundColor Green
            }

            # Write back JSON config
            $config | ConvertTo-Json -Depth 10 | Set-Content $wranglerPath
            Write-Host "[SUCCESS] wrangler.json updated successfully!" -ForegroundColor Green
        }
    }
    Write-Host

    # 4. Install dependencies and deploy worker
    Write-Host "[INFO] Installing dependencies..." -ForegroundColor Blue
    npm install

    Write-Host "[INFO] Deploying Worker to Cloudflare..." -ForegroundColor Blue
    $deployOutput = npx -y wrangler deploy 2>&1
    $deployOutputStr = Out-String -InputObject $deployOutput
    Write-Host $deployOutputStr

    # Extract worker URL
    $workerUrl = ""
    if ($deployOutputStr -match 'https://unlimited-temp-mail\.[a-zA-Z0-9-]+\.workers\.dev') {
        $workerUrl = $Matches[0]
        Write-Host "[SUCCESS] Worker deployed successfully!" -ForegroundColor Green
        Write-Host "Worker URL: $workerUrl" -ForegroundColor Yellow
    }
    Write-Host

    # 5. Cloudflare Email Routing instructions
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "⚡ CLOUDFLARE EMAIL ROUTING SETUP" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "To link your custom domain to this worker:"
    Write-Host "1. Go to Cloudflare Dashboard > [Your Domain] > Email Routing."
    Write-Host "2. Enable Email Routing."
    Write-Host "3. In 'Routes' > 'Catch-all address' > Click Edit."
    Write-Host "4. Action: Send to Worker."
    Write-Host "5. Destination: Select 'unlimited-temp-mail'."
    Write-Host "6. Click Save. Now all emails sent to your domain route to your Worker!" -ForegroundColor Green
    Write-Host

    # 6. Vercel deployment instructions
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "⚡ DEPLOY CLIENT DASHBOARD TO VERCEL" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "To host the beautiful client web dashboard for free:"
    Write-Host "1. Create a free account on Vercel."
    Write-Host "2. Install Vercel CLI locally (npm install -g vercel) or import to GitHub."
    Write-Host "3. In this project folder, run command:"
    Write-Host "   vercel --prod" -ForegroundColor Yellow
    Write-Host "4. Open the deployed Vercel URL, click 'Setup Config' and enter your Worker URL!" -ForegroundColor Green
    Write-Host

    Read-Host "Setup complete. Press Enter to exit..."
} catch {
    Write-Host "[ERROR] An unexpected error occurred: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit..."
}
