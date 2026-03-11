import os
import socket
import platform
from datetime import datetime, timezone
from flask import Flask, request, jsonify

app = Flask(__name__)

APP_SERVICE_NAME = os.environ.get("APP_SERVICE_NAME", "local")
REGION          = os.environ.get("REGION", "local")
INSTANCE_NUMBER = os.environ.get("INSTANCE_NUMBER", "1")
NETWORK_MODE    = os.environ.get("NETWORK_MODE", "Direct")
VERSION         = "2.0.0"

COLORS = ["#0078d4", "#00b294", "#d4380d", "#722ed1"]
color  = COLORS[hash(APP_SERVICE_NAME) % len(COLORS)]

# ── helpers ───────────────────────────────────────────────────────────────────

def get_network_headers():
    """Extract all network-path related headers injected by Front Door & App Gateway"""
    return {
        "x_forwarded_for":   request.headers.get("X-Forwarded-For", "not set"),
        "x_forwarded_host":  request.headers.get("X-Forwarded-Host", "not set"),
        "x_forwarded_proto": request.headers.get("X-Forwarded-Proto", "not set"),
        "x_azure_fdid":      request.headers.get("X-Azure-FDID", "not set"),
        "x_fd_health_probe": request.headers.get("X-FD-HealthProbe", "not set"),
        "x_appgw_clientip":  request.headers.get("X-AppGW-ClientIP", "not set"),
        "x_original_host":   request.headers.get("X-Original-Host", "not set"),
        "host":              request.headers.get("Host", "not set"),
    }

def build_request_path(headers):
    """Build human-readable request path based on headers present"""
    path = ["Internet"]
    if headers["x_azure_fdid"] != "not set":
        path.append("Azure Front Door")
    if NETWORK_MODE == "AppGateway":
        path.append("Application Gateway")
    path.append(f"App Service ({APP_SERVICE_NAME})")
    return " → ".join(path)

# ── routes ────────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    headers = get_network_headers()
    path    = build_request_path(headers)
    fd_active  = "active" if headers["x_azure_fdid"] != "not set" else ""
    agw_active = "active" if NETWORK_MODE == "AppGateway" else ""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Module 2 — {APP_SERVICE_NAME}</title>
  <style>
    * {{ margin:0; padding:0; box-sizing:border-box; }}
    body {{
      font-family: 'Segoe UI', sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
      min-height: 100vh; display: flex; align-items: center; justify-content: center;
    }}
    .card {{
      background: rgba(255,255,255,0.08); backdrop-filter: blur(20px);
      border: 1px solid rgba(255,255,255,0.15); border-radius: 20px; padding: 40px;
      max-width: 720px; width: 90%; box-shadow: 0 25px 45px rgba(0,0,0,0.3); color: #fff;
    }}
    .badge {{
      display: inline-block; background: {color}; color: white;
      padding: 4px 14px; border-radius: 20px; font-size: 12px;
      font-weight: 600; letter-spacing: 1px; text-transform: uppercase; margin-bottom: 16px;
    }}
    h1 {{ font-size: 28px; font-weight: 700; margin-bottom: 8px; }}
    .subtitle {{ color: rgba(255,255,255,0.6); margin-bottom: 28px; font-size: 14px; }}
    .arch-path {{
      background: rgba(0,0,0,0.3); border: 1px solid {color};
      border-radius: 10px; padding: 16px 20px; margin-bottom: 16px;
    }}
    .arch-label {{ font-size: 11px; color: rgba(255,255,255,0.4); margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px; }}
    .arch-steps {{ display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }}
    .arch-step {{
      background: rgba(255,255,255,0.08); border-radius: 6px;
      padding: 6px 12px; font-size: 12px; font-weight: 600; opacity: 0.5;
    }}
    .arch-step.active {{ background: {color}; opacity: 1; }}
    .arch-arrow {{ color: rgba(255,255,255,0.3); font-size: 16px; }}
    .detected-path {{
      background: rgba(0,120,60,0.2); border: 1px solid rgba(0,200,100,0.3);
      border-radius: 8px; padding: 10px 14px; margin-bottom: 20px;
      font-size: 13px; color: #00e676; font-family: monospace;
    }}
    .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-bottom: 24px; }}
    .info-item {{ background: rgba(0,0,0,0.2); border-radius: 10px; padding: 12px 16px; }}
    .info-label {{ font-size: 11px; color: rgba(255,255,255,0.4); text-transform: uppercase; letter-spacing: 1px; }}
    .info-value {{ font-size: 15px; font-weight: 600; margin-top: 3px; }}
    .links {{ display: flex; gap: 10px; flex-wrap: wrap; }}
    .link {{
      padding: 8px 18px; border-radius: 8px; font-size: 13px; font-weight: 600;
      text-decoration: none; transition: opacity 0.2s;
      background: rgba(255,255,255,0.1); color: white; border: 1px solid rgba(255,255,255,0.2);
    }}
    .link:hover {{ opacity: 0.8; }}
    .link.primary {{ background: {color}; border-color: {color}; }}
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">Module 2 — App Gateway Architecture</div>
    <h1>{APP_SERVICE_NAME}</h1>
    <p class="subtitle">Front Door + WAF → App Gateway → App Service (Zero Trust)</p>

    <div class="arch-path">
      <div class="arch-label">Architecture Path (active = lit up)</div>
      <div class="arch-steps">
        <div class="arch-step active">🌐 Internet</div>
        <div class="arch-arrow">→</div>
        <div class="arch-step {fd_active}">🛡️ Front Door + WAF</div>
        <div class="arch-arrow">→</div>
        <div class="arch-step {agw_active}">⚖️ App Gateway</div>
        <div class="arch-arrow">→</div>
        <div class="arch-step active">🖥️ {APP_SERVICE_NAME}</div>
      </div>
    </div>

    <div class="detected-path">🛣️ {path}</div>

    <div class="grid">
      <div class="info-item">
        <div class="info-label">App Service</div>
        <div class="info-value">{APP_SERVICE_NAME}</div>
      </div>
      <div class="info-item">
        <div class="info-label">Region</div>
        <div class="info-value">{REGION}</div>
      </div>
      <div class="info-item">
        <div class="info-label">Instance</div>
        <div class="info-value">#{INSTANCE_NUMBER}</div>
      </div>
      <div class="info-item">
        <div class="info-label">Version</div>
        <div class="info-value">{VERSION}</div>
      </div>
    </div>

    <div class="links">
      <a class="link primary" href="/network">🔍 Network Path</a>
      <a class="link" href="/health">💚 Health Check</a>
      <a class="link" href="/info">ℹ️ App Info</a>
    </div>
  </div>
</body>
</html>"""


@app.route("/health")
def health():
    return jsonify({
        "status":       "healthy",
        "app_service":  APP_SERVICE_NAME,
        "region":       REGION,
        "instance":     INSTANCE_NUMBER,
        "network_mode": NETWORK_MODE,
        "version":      VERSION,
        "hostname":     socket.gethostname(),
        "timestamp":    datetime.now(timezone.utc).isoformat()
    })


@app.route("/info")
def info():
    return jsonify({
        "app_service":  APP_SERVICE_NAME,
        "region":       REGION,
        "instance":     INSTANCE_NUMBER,
        "network_mode": NETWORK_MODE,
        "version":      VERSION,
        "hostname":     socket.gethostname(),
        "python":       platform.python_version(),
        "timestamp":    datetime.now(timezone.utc).isoformat()
    })


@app.route("/network")
def network():
    headers = get_network_headers()
    path    = build_request_path(headers)

    # Parse X-Forwarded-For hops
    xff  = headers["x_forwarded_for"]
    hops = [h.strip() for h in xff.split(",")] if xff != "not set" else []

    return jsonify({
        "request_path":  path,
        "app_service":   APP_SERVICE_NAME,
        "region":        REGION,
        "instance":      INSTANCE_NUMBER,
        "network_mode":  NETWORK_MODE,
        "version":       VERSION,
        "hostname":      socket.gethostname(),
        "network_headers": headers,
        "forwarded_for_hops": {
            "hop_0_client_ip":     hops[0] if len(hops) > 0 else "not set",
            "hop_1_frontdoor_pop": hops[1] if len(hops) > 1 else "not set",
            "hop_2_appgateway_ip": hops[2] if len(hops) > 2 else "not set",
        },
        "header_explanations": {
            "x_azure_fdid":      "Set by Azure Front Door — proves request came through FD",
            "x_forwarded_for":   "Chain: client IP → FD edge PoP → App Gateway private IP",
            "x_forwarded_proto": "Protocol used by client (https)",
            "x_original_host":   "App Gateway public IP — shows FD forwarded to App GW",
        },
        "timestamp": datetime.now(timezone.utc).isoformat()
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=False)
