# Technical Reference — Module 2: Front Door + App Gateway + App Services

> Interview preparation guide and deep-dive technical documentation.
> See also: [Module 1 Technical Reference](https://github.com/gsanjaykumar/azure-frontdoor-terraform/blob/main/TECHNICAL_REFERENCE.md)

---

## 1. Architecture Overview

### Resource Inventory

| Resource | Name Pattern | SKU/Tier | Purpose |
|----------|-------------|----------|---------|
| Resource Group | rg-appgateway-demo | — | Container for all resources |
| Virtual Network | vnet-appgateway-demo | — | Private network (10.0.0.0/16) |
| Subnet — App GW | snet-appgateway | 10.0.1.0/24 | App Gateway deployment |
| Subnet — App Svc | snet-appservice-integration | 10.0.2.0/24 | App Service VNet outbound |
| Subnet — PE | snet-private-endpoints | 10.0.3.0/24 | Private Link NAT IPs |
| NSG | nsg-appgateway-demo | — | L4 firewall for App GW subnet |
| Public IP | pip-appgateway-demo | Standard Static | App Gateway frontend |
| Application Gateway | agw-appgateway-demo | Standard_v2 | Regional L7 load balancer |
| Private Link Service | pls-appgateway-demo | — | Front Door Premium connection |
| App Service Plan | asp-appgateway-demo | B1 Linux | Hosts App Services |
| App Service (×2) | app-agw-dev-1/2 | B1 | Python 3.12 Flask apps |
| Front Door | afd-appgateway-demo | Standard | Global L7, WAF, SSL |
| DNS Zone | naidusingh.in | — | Domain management |
| Log Analytics | law-appgateway-demo-xxx | PerGB2018 | Centralized logging |
| WAF Policy | appgatewaydemowafxxx | Standard | 3 custom WAF rules |

---

## 2. Virtual Network Concepts

### VNet and Subnets

```
Virtual Network: 10.0.0.0/16  (65,536 addresses)
│
├── snet-appgateway           10.0.1.0/24  (256 addresses)
│   ├── Application Gateway v2 deployed here
│   ├── NSG attached (required)
│   └── Private Link policies DISABLED (required for PLS)
│
├── snet-appservice-integration  10.0.2.0/24  (256 addresses)
│   ├── Delegated to: Microsoft.Web/serverFarms
│   ├── App Services use this for OUTBOUND traffic only
│   └── App Services themselves are NOT inside this subnet
│
└── snet-private-endpoints    10.0.3.0/24  (256 addresses)
    └── NAT IPs for Private Link Service
```

### Key Concept: App Service VNet Integration
```
MISCONCEPTION: App Service is INSIDE the VNet
REALITY:       App Service uses VNet integration for OUTBOUND traffic only

App Service lives in Azure's managed infrastructure
        ↓ VNet Integration (Swift Connection)
Outbound traffic routes THROUGH snet-appservice-integration
        ↓
Can reach resources inside the VNet (App GW, other VNet resources)
```

---

## 3. Network Security Group (NSG)

### Why Every Rule Matters

```
Priority 100: GatewayManager (65200-65535)
  ✅ CRITICAL — App Gateway v2 requires this for internal health checks
  ❌ Missing = App Gateway fails to provision or becomes unhealthy
  Source: GatewayManager service tag (Azure infrastructure)

Priority 110: AzureFrontDoor.Backend
  ✅ Actual traffic from Front Door to App Gateway
  Source: Front Door data plane IPs

Priority 120: AzureFrontDoor.FirstParty
  ✅ Front Door health probe traffic
  ❌ Missing = "ConnectionFailure" in FD health probe logs
  ⚠️ DIFFERENT service tag from traffic! Common mistake!
  Source: Front Door control plane IPs

Priority 130: AzureLoadBalancer
  ✅ Azure internal health checks
  Source: Azure internal (168.63.129.16)

Priority 140: Allow-Direct-HTTP-Test (optional)
  ⚠️ TESTING ONLY — disable in production!
  Allows direct browser → App Gateway for testing before FD is set up

Priority 4096: Deny-All-Inbound
  ✅ Default deny — blocks everything not explicitly allowed
```

---

## 4. Application Gateway v2

### Components

```
Application Gateway
├── Frontend IP Configuration
│   └── Public IP (Standard Static) ← MUST be Standard + Static
│
├── Listeners
│   ├── HTTP:80  ← receives from Front Door
│   └── HTTPS:443 (optional, needs SSL cert on App GW)
│
├── Backend Address Pool
│   └── FQDNs: [app-agw-dev-1.azurewebsites.net,
│                app-agw-dev-2.azurewebsites.net]
│
├── Backend HTTP Settings
│   ├── Protocol: HTTPS (App Services only accept HTTPS)
│   ├── Port: 443
│   ├── Certificate type: Public CA ← App Services use DigiCert/Microsoft
│   └── Pick hostname from backend: YES ← CRITICAL!
│
├── Health Probe
│   ├── Protocol: HTTPS
│   ├── Path: /health
│   ├── Pick hostname from backend settings: YES
│   └── Interval: 30s, Timeout: 30s, Threshold: 3
│
├── Routing Rules
│   └── Basic: listener-http → backendpool-appservices
│
└── Private Link Service (optional)
    └── NAT IP from snet-private-endpoints
```

### Why "Pick Hostname from Backend" is Critical

```
WITHOUT pick_host_name_from_backend = true:
  App Gateway sends Host: 10.0.1.x (its own IP)
  App Service receives: Host: 10.0.1.x
  App Service says: "I don't know this host" → 404 NOT FOUND ❌

WITH pick_host_name_from_backend = true:
  App Gateway sends Host: app-agw-dev-1.azurewebsites.net
  App Service receives correct hostname → 200 OK ✅
```

### Why Public CA (not Private CA) for Backend Certificate

```
App Services use certificates signed by:
  DigiCert → Microsoft → *.azurewebsites.net

This is a PUBLIC Certificate Authority chain.

App Gateway backend certificate types:
  Private CA = expects self-signed or internal CA cert → needs .CER upload ❌
  Public CA   = trusts DigiCert/Microsoft chain automatically ✅

Always select Public CA when backend is Azure App Services!
```

---

## 5. Private Link Service

### How Private Link Works

```
Standard SKU (public routing):
  Front Door Edge PoP
       ↓ Public internet
  App Gateway Public IP (20.x.x.x)
       ↓ VNet internal
  App Services

Premium SKU (private routing):
  Front Door Edge PoP
       ↓ Azure backbone (NEVER public internet)
  Private Endpoint (auto-created by Front Door)
       ↓
  Private Link Service (on App GW subnet)
       ↓
  App Gateway Frontend IP
       ↓
  App Services
```

### Private Link Service Components

```
azurerm_private_link_service:
  ├── NAT IP configuration
  │   ├── Subnet: snet-private-endpoints
  │   ├── Primary: true (at least 1 required)
  │   └── Allocation: Dynamic
  │
  └── Frontend IP association
      └── Points to App Gateway frontend IP config

LESSON LEARNED: Private Link Service form won't save without
at least 1 NAT IP configuration with Primary = true
```

### SKU Comparison for Private Link

| SKU | Cost/month | Private Link | When to use |
|-----|-----------|-------------|-------------|
| Standard | ~$35 | ❌ Not supported | Learning, dev, cost-sensitive |
| Premium | ~$330 | ✅ Supported | Production, enterprise, zero-trust |

> 💡 Premium is billed per hour (~$0.45/hr) — provision for learning and destroy immediately!

---

## 6. Traffic Flow (Detailed)

### Request Journey — Standard SKU

```
1. User browser
   DNS: www.naidusingh.in → Front Door anycast IP

2. Front Door edge PoP (nearest to user)
   ├── WAF: check rate limit, bad bots, geo filter
   ├── TLS termination (managed cert)
   ├── Route match: /* → og-appgateway-demo
   └── Forward HTTP to App Gateway Public IP

3. App Gateway (10.0.1.x)
   ├── NSG: validates source is AzureFrontDoor.Backend
   ├── HTTP listener: port 80 receives request
   ├── Routing rule: basic → backendpool
   ├── HTTP settings: override host → app-agw-dev-X.azurewebsites.net
   ├── Health probe: selects healthy backend
   └── Forward HTTPS to App Service

4. App Service
   ├── Access restriction: validates source is 10.0.1.0/24 ✅
   ├── Flask app processes request
   └── Returns response

5. Headers visible at App Service:
   X-Azure-FDID:     proves Front Door
   X-Forwarded-For:  client IP, FD PoP IP, App GW private IP (10.0.1.x)
   X-Original-Host:  App Gateway public IP
   X-Forwarded-Proto: https
```

---

## 7. App Service Access Restrictions

### How It Works

```
Azure App Service has a built-in firewall:
  ip_restriction {
    service_tag = "VirtualNetwork"   ← allow entire VNet
    action      = "Allow"
    priority    = 100
  }
  ip_restriction {
    ip_address = "0.0.0.0/0"        ← deny everything else
    action     = "Deny"
    priority   = 200
  }

Result:
  ✅ App Gateway → App Service (source: 10.0.1.x = VNet)
  ❌ Browser → app-agw-dev-1.azurewebsites.net (403 Forbidden)
  ❌ curl → App Service direct (403 Forbidden)
```

### Security Comparison: Module 1 vs Module 2

```
Module 1 (Header-based):
  Front Door adds: X-Azure-FDID header
  App Service checks header value → allows/denies
  WEAKNESS: Anyone who knows the FDID can spoof the header!

Module 2 (Subnet-based):
  App Gateway → App Service via private subnet
  App Service rejects anything not from 10.0.1.0/24
  STRENGTH: Network-level control — impossible to spoof!
```

---

## 8. Monitoring — Dual Diagnostic Settings

### Module 2 Enhancement Over Module 1

```
Module 1: 1 diagnostic setting (Front Door only)
Module 2: 2 diagnostic settings (Front Door + App Gateway)
```

### Log Categories

```
Front Door → Log Analytics:
  ├── FrontDoorAccessLog        all requests through FD
  ├── FrontDoorWebApplicationFirewallLog  WAF events
  └── FrontDoorHealthProbeLog   probe results per origin

App Gateway → Log Analytics:
  ├── ApplicationGatewayAccessLog    all requests to App GW
  ├── ApplicationGatewayFirewallLog  (WAF_v2 SKU only)
  └── ApplicationGatewayPerformanceLog  health/perf metrics
```

### Correlated Query — Full Request Journey

```kusto
// Shows both Front Door and App Gateway access logs together
// Correlate by RequestUri to trace same request through both layers
AzureDiagnostics
| where ResourceProvider in ("MICROSOFT.CDN", "MICROSOFT.NETWORK")
| where Category in ("FrontDoorAccessLog", "ApplicationGatewayAccessLog")
| project TimeGenerated, ResourceProvider, Category,
          requestUri_s, httpStatusCode_d, httpStatus_d,
          clientIp_s, clientIP_s
| order by TimeGenerated desc
| take 50
```

---

## 9. Terraform IaC Design

### Module Dependency Graph

```
azurerm_resource_group
         │
    ┌────┴────┐
    ▼         ▼
networking  dns_zone
    │         │
    │    ┌────┤
    ▼    ▼    │
app_services  │
    │         │
    ▼         │
app_gateway   │
    │         │
    └────┬────┘
         ▼
     front_door
         │
    ┌────┤
    ▼    ▼
dns_records  waf
```

### Key Terraform Patterns Used

```hcl
# 1. Conditional resource creation
resource "azurerm_private_link_service" "appgateway" {
  count = var.enable_private_link ? 1 : 0
  ...
}

# 2. Dynamic blocks
dynamic "private_link" {
  for_each = var.front_door_sku == "Premium_AzureFrontDoor" ? [1] : []
  content {
    private_link_target_id = var.private_link_service_id
  }
}

# 3. Data source for ZIP (non-deprecated pattern)
data "archive_file" "app_zip" {
  type       = "zip"
  source_dir = "${path.root}/app"
  output_path = "${path.root}/app.zip"
}

# 4. For_each for dynamic NSG rules
dynamic "domain" {
  for_each = var.front_door_domain_ids
  content {
    cdn_frontdoor_domain_id = domain.value
  }
}
```

---

## 10. Lessons Learned

| # | Issue | Root Cause | Fix | Impact |
|---|-------|-----------|-----|--------|
| 1 | App GW fails to provision | Missing GatewayManager NSG rule 65200-65535 | Add NSG rule | Critical |
| 2 | Front Door returns 404 | NSG missing AzureFrontDoor.FirstParty rule | Add NSG rule | High |
| 3 | Backend health Unknown | pick_host_name_from_backend = false | Set to true | High |
| 4 | HTTPS backend cert error | App GW defaults to Private CA | Select Public CA | High |
| 5 | Private Link not showing | Front Door Standard SKU limitation | Use Premium or skip | Medium |
| 6 | FD health probe fails | FD probing HTTPS, App GW listener on HTTP | Match protocols | Medium |
| 7 | PLS form won't save | No NAT IP configured | Add 1 Dynamic NAT IP | Medium |
| 8 | App deploy race condition | VNet integration restart cancels deploy | time_sleep 30s | Low |
| 9 | WAF events not logging | Hyphen in WAF/security policy name | Alphanumeric only | Low |
| 10 | DNS Zone new nameservers | Every recreate assigns new NS | Update GoDaddy | Info |
| 11 | WAF mode change delay | FD propagation to all edge PoPs | Wait 5-10 mins | Info |

---

## 11. Interview Questions & Answers

### Q1: Why use Application Gateway behind Front Door? Isn't Front Door enough?

**A**: They serve different purposes at different OSI layers:
- **Front Door**: Global, anycast, CDN, closest PoP → user. Handles SSL globally.
- **Application Gateway**: Regional, VNet-native, path-based routing, integrates with VNet resources.

Together: FD handles global traffic distribution, App GW handles regional routing with VNet integration. You also get **two layers of load balancing** — global + regional.

---

### Q2: How is App Service access restricted in this architecture?

**A**: Two mechanisms work together:
1. **VNet Integration** connects App Service outbound traffic to the VNet
2. **Access Restriction** with `service_tag = "VirtualNetwork"` only allows traffic from within the VNet (specifically 10.0.1.0/24 App GW subnet)

This is **network-level restriction** — unlike Module 1's header-based approach, this cannot be spoofed.

---

### Q3: Why does App Gateway need a Standard Static Public IP?

**A**: App Gateway v2 requires:
- **Standard SKU**: Supports zone redundancy and dynamic scaling
- **Static allocation**: The IP must not change (Front Door origin is configured with this IP)

Basic SKU or Dynamic allocation causes provisioning failures.

---

### Q4: What is the GatewayManager NSG rule and why is it critical?

**A**: Azure uses the IP range 65200-65535 to communicate between its infrastructure and your App Gateway instances for health checks, configuration updates, and scaling operations. Without this rule, App Gateway cannot function — it will fail to provision or go into a failed state. The source must be the `GatewayManager` service tag.

---

### Q5: Explain the difference between AzureFrontDoor.Backend and AzureFrontDoor.FirstParty service tags.

**A**:
- **AzureFrontDoor.Backend**: Data plane — actual user traffic forwarded from Front Door to your origin
- **AzureFrontDoor.FirstParty**: Control plane — health probe traffic from Front Door monitoring

Both are needed in NSG rules! A common mistake is adding only Backend, which allows traffic but blocks probes — Front Door then marks the origin as unhealthy and stops sending traffic.

---

### Q6: How does Private Link improve security over standard routing?

**A**: Without Private Link (Standard SKU):
```
Front Door → Public internet → App Gateway Public IP
```
The traffic between Front Door's edge and App Gateway traverses the public internet (though encrypted).

With Private Link (Premium SKU):
```
Front Door → Azure backbone → Private Endpoint → Private Link Service → App Gateway
```
Traffic **never touches the public internet** — it stays entirely on Azure's private backbone. This is the zero-trust networking pattern used in enterprise/banking environments.

---

### Q7: What headers prove a request went through Front Door and App Gateway?

**A**:
- `X-Azure-FDID`: Unique Front Door profile ID — proves Front Door processed it
- `X-Forwarded-For`: Chain of IPs — includes client IP, FD edge PoP IP, App GW private IP (10.0.1.x)
- `X-Original-Host`: App Gateway public IP — proves FD forwarded to App GW

The `10.0.1.x` private IP in `X-Forwarded-For` is particularly powerful evidence — it's a RFC 1918 address only present when App GW is inside a VNet.

---

### Q8: Why is waf_mode = "Detection" recommended initially?

**A**: In Prevention mode, the WAF actively blocks requests. If misconfigured (wrong geo filter, too-low rate limit), it could block legitimate users — potentially taking down production traffic. Detection mode logs what **would** be blocked without actually blocking. After reviewing the logs for false positives, switch to Prevention mode with confidence.

---

### Q9: What is the deployment order and why?

**A**: The order resolves dependencies:
1. `networking` first — subnets must exist before App GW
2. `dns_zone` first — no dependencies, needed by FD for custom domain
3. `app_services` — needs networking (VNet integration subnet)
4. `app_gateway` — needs networking (App GW subnet) + app_services (backend FQDNs)
5. `front_door` — needs app_gateway (origin IP) + dns_zone (custom domain)
6. `dns_records` — needs front_door (validation token)
7. `waf` — needs front_door (domain IDs) + app_gateway (diagnostic settings target)

---

### Q10: How would you upgrade from Standard to Premium SKU to enable Private Link?

**A**: In `terraform.tfvars`:
```hcl
front_door_sku = "Premium_AzureFrontDoor"
```
Terraform will:
1. Recreate the Front Door profile with Premium SKU
2. Enable the Private Link origin (via `dynamic "private_link"` block)
3. Create the Private Link Service on App Gateway (via `enable_private_link = true`)

After apply, you must **manually approve** the Private Link connection request in Azure Portal → App Gateway → Private Link → Pending connections. This is an Azure security requirement that cannot be automated.
