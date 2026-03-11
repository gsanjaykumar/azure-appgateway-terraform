# Module 2: Azure Front Door + Application Gateway + App Services

> **Learning Series** | [Module 1: Front Door + App Services](https://github.com/gsanjaykumar/azure-frontdoor-terraform) | **Module 2: + App Gateway (this repo)**

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                          INTERNET                                │
└──────────────────────────────┬───────────────────────────────────┘
                               │ HTTPS
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│               AZURE FRONT DOOR STANDARD/PREMIUM                  │
│         WAF Policy │ Global LB │ SSL │ Custom Domain             │
└──────────────────────────────┬───────────────────────────────────┘
                               │ HTTP (Standard) / Private Link (Premium)
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│              AZURE VIRTUAL NETWORK (10.0.0.0/16)                 │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │        snet-appgateway (10.0.1.0/24)                       │  │
│  │        APPLICATION GATEWAY v2 (Standard_v2)                │  │
│  │        Path routing │ Health probes │ SSL offload           │  │
│  └────────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │        snet-appservice-integration (10.0.2.0/24)           │  │
│  │        [Delegated: Microsoft.Web/serverFarms]              │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬───────────────────────────────────┘
                               │ HTTPS (App GW → App Services)
                               │ Access Restriction: only 10.0.1.0/24
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                    AZURE APP SERVICES (×2)                       │
│               Python 3.12 │ Flask 3.0 │ B1 Linux                 │
│               🔒 Public access: BLOCKED                          │
│               ✅ App Gateway subnet only                         │
└──────────────────────────────────────────────────────────────────┘
```

## Security Layers

| Layer | Component | What it does |
|-------|-----------|-------------|
| 1 | Front Door WAF | Rate limit, bad bot blocking, geo filtering |
| 2 | NSG | Only allows Front Door service tags + GatewayManager |
| 3 | Application Gateway | Regional L7 load balancing, health probes |
| 4 | App Service Access Restriction | Blocks all traffic except App GW subnet |

## Features

- ✅ **Azure Virtual Network** — 3 subnets, NSG with all required rules
- ✅ **Application Gateway v2** — regional load balancing, path-based routing
- ✅ **Private Link Service** — optional (requires Front Door Premium SKU)
- ✅ **App Services locked down** — truly private via subnet-based restrictions
- ✅ **VNet Integration** — App Services connected to VNet for outbound traffic
- ✅ **WAF Policy** — 3 custom rules (rate limit, bad bots, geo filter)
- ✅ **Dual Monitoring** — Log Analytics captures both Front Door + App Gateway logs
- ✅ **Custom Domain + SSL** — managed certificate via Azure Front Door
- ✅ **GitHub Actions CI/CD** — validate on PR, apply on merge

## What's Different from Module 1

| | Module 1 | Module 2 |
|---|---|---|
| Network | No VNet | VNet 10.0.0.0/16 + 3 subnets |
| Origin | Public App Service hostname | App Gateway public IP |
| App Service access | Header-based restriction | Subnet-based (truly private) ✅ |
| Load balancing | Front Door only (global) | Front Door + App GW (global + regional) |
| Private Link | ❌ Not supported (Standard) | ✅ Supported (Premium SKU) |
| Monitoring | Front Door logs only | Front Door + App Gateway logs |
| New concepts | — | VNet, NSG, App GW, Private Link |
| Cost/month | ~$35 | ~$200 |

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | >= 1.5.0 | Infrastructure as Code |
| Azure CLI | Latest | Authentication + ZIP deploy |
| Git | Any | Version control |
| Azure subscription | — | Target environment |
| Domain name | — | Custom domain (optional) |

## Quick Start

### 1. Clone and configure
```bash
git clone https://github.com/gsanjaykumar/azure-appgateway-terraform.git
cd azure-appgateway-terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Authenticate to Azure
```bash
az login
az account set --subscription "your-subscription-id"
```

### 3. Initialize Terraform
```bash
terraform init
```

### 4. Plan and review
```bash
terraform plan
```

### 5. Deploy
```bash
terraform apply
```

> ⏳ **App Gateway takes 5-7 minutes to provision**. Total deployment: ~15-20 minutes.

### 6. Verify deployment
```powershell
# Get outputs
terraform output deployment_summary

# Test health endpoint
Invoke-WebRequest -Uri "$(terraform output -raw front_door_endpoint_url)/health"

# Test network path (shows full request journey)
Invoke-WebRequest -Uri "$(terraform output -raw front_door_endpoint_url)/network"

# Verify App Service is locked down (should return 403)
Invoke-WebRequest -Uri "$(terraform output -json app_service_urls | ConvertFrom-Json)[0]"
```

## Module Structure

```
modules/
├── networking/       VNet + 3 subnets + NSG rules
├── app_services/     App Services + VNet integration + access restrictions
├── app_gateway/      App Gateway v2 + Public IP + Private Link Service
├── front_door/       Front Door profile + origin (App GW) + custom domain
├── dns_zone/         Azure DNS Zone (no dependencies — breaks circular dep)
├── dns_records/      TXT validation + CNAME records
└── waf/              Log Analytics + FD & AGW diagnostics + WAF policy
```

## Deployment Order

```
Step 1  networking       VNet + subnets + NSG
Step 2  dns_zone         Azure DNS Zone
Step 3  app_services     Python Flask apps (VNet integrated, locked down)
Step 4  app_gateway      App GW v2 + Public IP + Private Link Service
Step 5  front_door       FD with App GW as origin + custom domain
Step 6  dns_records      TXT + CNAME records
Step 7  waf              LAW + diagnostics (FD + AGW) + WAF policy
```

## NSG Rules (Critical)

| Priority | Rule | Source | Ports | Why |
|----------|------|--------|-------|-----|
| 100 | Allow-GatewayManager | GatewayManager | 65200-65535 | **REQUIRED** — App GW v2 health |
| 110 | Allow-FrontDoor-Backend | AzureFrontDoor.Backend | 80, 443 | Traffic forwarding |
| 120 | Allow-FrontDoor-FirstParty | AzureFrontDoor.FirstParty | 80, 443 | Health probes |
| 130 | Allow-AzureLoadBalancer | AzureLoadBalancer | * | Azure internal |
| 140 | Allow-Direct-HTTP-Test | Internet | 80 | Testing only (disable in prod) |
| 4096 | Deny-All-Inbound | Any | * | Default deny |

> ⚠️ Missing the **GatewayManager** rule is the #1 cause of App Gateway provisioning failures!

## WAF Rules

| Priority | Rule | Type | Action |
|----------|------|------|--------|
| 1 | RateLimitRule | Rate Limit | Block if >100 req/min/IP |
| 2 | BlockBadBots | Match | Block sqlmap, nikto, nmap, masscan |
| 3 | GeoFilterRule | Match | Block all countries except allowed list |

## Flask App Endpoints

| Endpoint | Response | Purpose |
|----------|----------|---------|
| `GET /` | HTML | Visual dashboard with architecture path diagram |
| `GET /health` | JSON | Health check for App GW + Front Door probes |
| `GET /info` | JSON | App Service metadata |
| `GET /network` | JSON | **Full network path with all headers explained** |

### Sample `/network` response
```json
{
  "request_path": "Internet → Azure Front Door → Application Gateway → App Service (app-agw-dev-1)",
  "x_azure_fdid": "90a49080-b3d5-xxxx",
  "forwarded_for_hops": {
    "hop_0_client_ip": "124.123.x.x",
    "hop_1_frontdoor_pop": "147.243.x.x",
    "hop_2_appgateway_ip": "10.0.1.5"
  }
}
```

> The private IP `10.0.1.5` in hop 2 proves traffic flows through the **App Gateway inside your VNet**!

## Front Door SKU Options

```hcl
# Standard (default) — ~$35/month
# Traffic: Front Door → public internet → App Gateway
front_door_sku = "Standard_AzureFrontDoor"

# Premium — ~$330/month but billed per hour!
# Traffic: Front Door → Private Link → App Gateway (never touches public internet)
front_door_sku = "Premium_AzureFrontDoor"
```

## KQL Queries (Log Analytics)

### Front Door Access Logs
```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.CDN"
| where Category == "FrontDoorAccessLog"
| project TimeGenerated, requestUri_s, httpStatusCode_d, clientIp_s, userAgent_s
| order by TimeGenerated desc
| take 50
```

### App Gateway Access Logs
```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.NETWORK"
| where Category == "ApplicationGatewayAccessLog"
| project TimeGenerated, requestUri_s, httpStatus_d, clientIP_s, serverRouted_s
| order by TimeGenerated desc
| take 50
```

### Combined — Full Request Journey
```kusto
AzureDiagnostics
| where ResourceProvider in ("MICROSOFT.CDN", "MICROSOFT.NETWORK")
| where Category in ("FrontDoorAccessLog", "ApplicationGatewayAccessLog")
| project TimeGenerated, ResourceProvider, Category, requestUri_s
| order by TimeGenerated desc
| take 50
```

### WAF Blocked Requests
```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.CDN"
| where Category == "FrontDoorWebApplicationFirewallLog"
| where action_s == "Block"
| project TimeGenerated, clientIP_s, requestUri_s, ruleName_s, action_s
| order by TimeGenerated desc
```

## Destroy Resources

```bash
terraform destroy
```

> ⚠️ App Gateway takes longer to destroy. If it times out, run destroy again.
> ⚠️ DNS Zone deletion assigns new nameservers — update GoDaddy after each recreate!

## Known Issues & Fixes

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| App GW fails to provision | Missing GatewayManager NSG rule | Add rule 65200-65535 from GatewayManager |
| Front Door returns 404 | NSG missing FrontDoor.FirstParty rule | Add rule for AzureFrontDoor.FirstParty |
| Backend health Unknown/Unhealthy | Wrong hostname in HTTP settings | Enable pick_host_name_from_backend |
| HTTPS backend cert error | App GW defaulting to private CA | Set certificate type to Public CA |
| Private Link not in Standard FD | SKU limitation | Use Premium SKU or skip Private Link |
| FD probe ConnectionFailure | FD probing HTTPS, App GW on HTTP | Match FD probe protocol to App GW listener |
| App deploy race condition | VNet integration restart cancels deploy | Add time_sleep 30s before ZIP deploy |
| WAF events not logging | Hyphen in WAF policy name | Use alphanumeric only (no hyphens!) |

## Security Notes

- `terraform.tfvars` is gitignored — never commit real values
- App Services have no public access — only reachable via App Gateway subnet
- WAF starts in Detection mode — review logs before switching to Prevention
- Use `enable_direct_access = false` in production (disables direct internet → App GW)

## References

- [Azure Application Gateway documentation](https://docs.microsoft.com/en-us/azure/application-gateway/)
- [Azure Front Door documentation](https://docs.microsoft.com/en-us/azure/frontdoor/)
- [Azure Private Link documentation](https://docs.microsoft.com/en-us/azure/private-link/)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
