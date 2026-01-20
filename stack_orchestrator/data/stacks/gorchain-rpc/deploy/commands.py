from stack_orchestrator.deploy.deployment_context import DeploymentContext


def create(context: DeploymentContext, extra_args):
    """Stack deploy hook - no-op since TLS is handled by Caddy ingress."""
    pass
