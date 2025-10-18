import sys
from argparse import ArgumentParser
from pathlib import Path
from shutil import copyfile

from stack_orchestrator.deploy.deploy_types import DeployCommandContext


def create(deployment_context: DeployCommandContext, extra_args):
    "Copy SSL certificate and private key files into deployment config directory."

    parser = ArgumentParser()
    parser.add_argument('--private-key-file', type=Path, required=True)
    parser.add_argument('--certificate-file', type=Path, required=True)

    args = parser.parse_args(extra_args)
    privkey_file = args.private_key_file
    cert_file = args.certificate_file

    if not cert_file.exists():
        print(f"Error: certificate file does not exist: {cert_file}")
        sys.exit(1)

    if not privkey_file.exists():
        print(f"Error: private key file does not exist: {privkey_file}")
        sys.exit(1)

    # Create config directory if it doesn't exist
    deployment_config_dir = deployment_context.deployment_dir.joinpath("config")
    deployment_config_dir.mkdir(parents=True, exist_ok=True)

    # Copy certificate file as origin.cert.pem
    dest_cert = deployment_config_dir.joinpath("origin.cert.pem")
    copyfile(cert_file, dest_cert)
    print(f"Copied certificate: {cert_file} -> {dest_cert}")

    # Copy private key file as origin.key
    dest_key = deployment_config_dir.joinpath("origin.key")
    copyfile(privkey_file, dest_key)
    print(f"Copied private key: {privkey_file} -> {dest_key}")

    print("SSL certificate and key files successfully copied to deployment config directory")

    return None
