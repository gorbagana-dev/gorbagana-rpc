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
    """Stack deploy hook - no-op since TLS is handled by Caddy ingress."""
    pass
