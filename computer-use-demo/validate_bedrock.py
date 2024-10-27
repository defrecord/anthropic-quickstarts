#!/usr/bin/env python3

import ast
import boto3
from botocore.exceptions import ClientError, BotoCoreError
import click
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
import json
import os
import sys


@dataclass
class ModelConfig:
    """Represents a model configuration found in the source code."""
    provider: str
    model_id: str
    file_path: Path
    line_number: int

    def __str__(self) -> str:
        return f"{self.provider}: {self.model_id} ({self.file_path}:{self.line_number})"


class ModelConfigVisitor(ast.NodeVisitor):
    """AST visitor to find model configuration in Python source code."""

    def __init__(self):
        self.configs: List[ModelConfig] = []
        self._current_file: Optional[Path] = None

    def visit_AnnAssign(self, node: ast.AnnAssign) -> None:
        """Visit annotated assignments to find model configurations."""
        if isinstance(node.target, ast.Name) and isinstance(
                node.annotation, ast.Subscript):
            if "PROVIDER_TO_DEFAULT_MODEL_NAME" in ast.unparse(node.target):
                if isinstance(node.value, ast.Dict):
                    for key, value in zip(node.value.keys, node.value.values):
                        if isinstance(key, ast.Attribute) and isinstance(
                                value, ast.Constant):
                            provider = ast.unparse(key)
                            model_id = value.value
                            self.configs.append(
                                ModelConfig(provider=provider,
                                            model_id=model_id,
                                            file_path=self._current_file,
                                            line_number=getattr(
                                                key, 'lineno', 0)))
        self.generic_visit(node)


class BedrockValidator:
    """Validates AWS Bedrock model availability and configuration."""

    def __init__(self, region: str):
        """Initialize the Bedrock validator."""
        self.region = region
        try:
            self.bedrock_client = boto3.client('bedrock', region_name=region)
            self.sts_client = boto3.client('sts')
        except Exception as e:
            click.secho(f"Failed to initialize AWS clients: {e}",
                        fg='red',
                        err=True)
            raise

    def validate_credentials(self) -> Tuple[bool, str]:
        """Validate AWS credentials."""
        try:
            identity = self.sts_client.get_caller_identity()
            return True, f"Authenticated as: {identity['Arn']}"
        except Exception as e:
            return False, f"AWS authentication failed: {e}"

    def list_available_models(self) -> List[Dict[str, Any]]:
        """Get list of available Bedrock models."""
        try:
            response = self.bedrock_client.list_foundation_models()
            return [
                model for model in response.get('modelSummaries', [])
                if model.get('modelLifecycle', {}).get('status') == 'ACTIVE'
            ]
        except Exception as e:
            click.secho(f"Failed to list Bedrock models: {e}",
                        fg='red',
                        err=True)
            return []

    def validate_model(self, model_id: str) -> Tuple[bool, str]:
        """Validate if a specific model is available and supported."""
        available_models = self.list_available_models()

        target_model = next(
            (m for m in available_models if m['modelId'] == model_id), None)

        if not target_model:
            claude_models = [
                m['modelId'] for m in available_models
                if 'claude' in m['modelId'].lower()
            ]
            return False, f"""Model {model_id} not found in region {self.region}.

Available Claude models:
{json.dumps(claude_models, indent=2)}

Please ensure you have requested access to this model in the AWS Console:
https://console.aws.amazon.com/bedrock/home?region={self.region}#/modelaccess"""

        # Check capabilities
        has_text_input = 'TEXT' in target_model.get('inputModalities', [])
        has_text_output = 'TEXT' in target_model.get('outputModalities', [])
        has_streaming = target_model.get('responseStreamingSupported', False)

        if not all([has_text_input, has_text_output, has_streaming]):
            return False, f"Model {model_id} missing required capabilities"

        return True, f"Model {model_id} is available and supported"


def find_model_configs(source_dir: Path) -> List[ModelConfig]:
    """Find model configurations in Python source files."""
    visitor = ModelConfigVisitor()

    for py_file in source_dir.rglob("*.py"):
        try:
            with open(py_file, 'r') as f:
                tree = ast.parse(f.read(), filename=str(py_file))
            visitor._current_file = py_file
            visitor.visit(tree)
        except SyntaxError as e:
            click.secho(f"Error parsing {py_file}: {e}", fg='red', err=True)

    return visitor.configs


@click.command()
@click.option('--source-dir',
              type=click.Path(exists=True, file_okay=False, path_type=Path),
              default='.',
              help='Source directory to scan')
@click.option('--region', default='us-west-2', help='AWS region to check')
@click.option('--verbose', is_flag=True, help='Show detailed output')
def main(source_dir: Path, region: str, verbose: bool) -> None:
    """Validate Bedrock configuration and model availability."""
    click.secho("\n=== Bedrock Configuration Validator ===\n",
                fg='blue',
                bold=True)

    # Show validation context
    click.secho("Validation Context:", fg='blue')
    click.echo(f"• Source Directory: {source_dir}")
    click.echo(f"• Target Region: {region}")
    click.echo(f"• Python Version: {sys.version.split()[0]}")
    click.echo()

    try:
        # Find model configurations
        configs = find_model_configs(source_dir)
        bedrock_configs = [c for c in configs if "BEDROCK" in c.provider]

        if not bedrock_configs:
            click.secho("✗ No Bedrock configurations found!", fg='red')
            return 1

        config = bedrock_configs[0]
        click.secho(f"Found configuration: {config}", fg='green')

        # Initialize validator
        validator = BedrockValidator(region)

        # Check AWS credentials
        click.secho("\nChecking AWS credentials...", fg='blue')
        creds_valid, creds_message = validator.validate_credentials()
        if creds_valid:
            click.secho(f"✓ {creds_message}", fg='green')
        else:
            click.secho(f"✗ {creds_message}", fg='red')
            return 1

        # Check model availability
        click.secho("\nChecking model availability...", fg='blue')
        model_valid, model_message = validator.validate_model(config.model_id)
        if model_valid:
            click.secho(f"✓ {model_message}", fg='green')
        else:
            click.secho(f"✗ {model_message}", fg='red')
            return 1

        click.secho("\n✅ All validation checks passed!", fg='green', bold=True)
        return 0

    except Exception as e:
        click.secho(f"Error during validation: {str(e)}", fg='red', err=True)
        if verbose:
            import traceback
            click.echo("\nStacktrace:")
            click.echo(traceback.format_exc())
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
