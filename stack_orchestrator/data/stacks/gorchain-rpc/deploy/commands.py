import sys
from argparse import ArgumentParser
from pathlib import Path
from shutil import copyfile

from stack_orchestrator.deploy.deployment_context import DeploymentContext


def create(context: DeploymentContext, extra_args):
    "Copy SSL certificate and private key files into deployment config directory."

    parser = ArgumentParser()
    parser.add_argument('--private-key-file', type=Path, default=None)
    parser.add_argument('--certificate-file', type=Path, default=None)
    args = parser.parse_args(extra_args)

    # Create config directory if it doesn't exist
    deployment_certs_dir = context.deployment_dir / "config" / "certs"
    deployment_certs_dir.mkdir(parents=True, exist_ok=True)

    if cert_file := args.certificate_file:
        if not cert_file.exists():
            print(f"Error: certificate file does not exist: {cert_file}")
            sys.exit(1)

        dest_cert = deployment_certs_dir / "origin.cert.pem"
        copyfile(cert_file, dest_cert)
        print(f"Copied certificate: {cert_file} -> {dest_cert}")
    else:
        print("Warning: no certificate file passed")

    if privkey_file := args.private_key_file:
        if not privkey_file.exists():
            print(f"Error: private key file does not exist: {privkey_file}")
            sys.exit(1)

        dest_key = deployment_certs_dir / "origin.key"
        copyfile(privkey_file, dest_key)
        print(f"Copied private key: {privkey_file} -> {dest_key}")
    else:
        print("Warning: no private key file passed")

    # Update the compose file to use deployment certs instead of dev certs
    compose_file = context.get_compose_file("gorchain-rpc")

    replacements = {
        '../config/gorchain/dev-certs/dev-cert.pem': '../config/certs/origin.cert.pem',
        '../config/gorchain/dev-certs/dev-private-key.pem': '../config/certs/origin.key',
    }
    def replace_cert_paths(yaml_data):
        volumes = yaml_data['services']['envoy-proxy'].get('volumes', [])
        for i, vol in enumerate(volumes):
            # Replace dev cert paths with deployment cert paths
            host_location = vol.split(':')[0]
            if host_location in replacements:
                volumes[i] = vol.replace(host_location, replacements[host_location])

    context.modify_yaml(compose_file, replace_cert_paths)
    print("Updated compose file to use deployment certificates")

    return None
