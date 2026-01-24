from pathlib import Path
from stack_orchestrator.deploy.deployment_context import DeploymentContext


def init(deploy_command_context):
    """Return default spec content for this stack.

    Provides:
    - http-proxy configuration for ingress routing (host-name can be overridden via config)
    - security settings for unlimited memlock (required for Solana/Agave validators)
    """
    return {
        "network": {
            "http-proxy": [
                {
                    "host-name": "rpc.gorbagana.wtf",
                    "routes": [
                        {
                            "path": "/",
                            "proxy-to": "agave-rpc:8899"
                        },
                        {
                            "path": "/",
                            "proxy-to": "agave-rpc:8900",
                            "websocket": True
                        }
                    ]
                }
            ]
        },
        "security": {
            "privileged": True,
            "unlimited-memlock": True,
            "capabilities": ["IPC_LOCK"],
        }
    }


def create(context: DeploymentContext, extra_args):
    """Apply WebSocket fix after deployment - patches Caddy for HTTP/1.1 and WS route."""
    import subprocess

    # Check if any routes have websocket: true
    http_proxy_list = context.spec.obj.get("network", {}).get("http-proxy", [])
    ws_routes = []
    for http_proxy in http_proxy_list:
        host_name = http_proxy.get("host-name")
        for route in http_proxy.get("routes", []):
            if route.get("websocket"):
                proxy_to = route.get("proxy-to", "")
                if ":" in proxy_to:
                    ws_port = proxy_to.split(":")[1]
                    ws_routes.append((host_name, ws_port))

    if not ws_routes:
        return

    # Build service FQDN
    service_fqdn = f"{context.id}-service.default.svc.cluster.local"

    # Path to patch script
    script_path = Path(__file__).parent / "patch-caddy-websocket.sh"

    for host_name, ws_port in ws_routes:
        print(f"Applying WebSocket patch for {host_name}:{ws_port}...")
        result = subprocess.run(
            ["bash", str(script_path), service_fqdn, host_name, ws_port],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print(f"Warning: {result.stderr}")
