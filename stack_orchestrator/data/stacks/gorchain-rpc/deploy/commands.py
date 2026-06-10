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
                    "host-name": "www.example.com",
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
            ],
            "acme-email": "admin@example.com"
        },
        "security": {
            "privileged": True,
            "unlimited-memlock": True,
            "capabilities": ["IPC_LOCK"],
        }
    }

