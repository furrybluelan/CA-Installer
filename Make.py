#!/usr/bin/env python3
"""
Build script for CA Installer Magisk module.
Compiles Java code to DEX, generates checksums, and creates the installable ZIP.
"""

import hashlib
import logging
import shutil
import subprocess
import sys
from pathlib import Path
from typing import List, Optional  # noqa: F401


# Configure logging
logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)


class BuildError(Exception):
    """Custom exception for build errors."""

    pass


class Builder:
    """Main builder class for CA Installer module."""

    MODULE_DIR = Path("Module")
    CERT_NAME_JAVA = Path("SystemCertificateName.java")
    CERT_NAME_CLASS = Path("SystemCertificateName.class")
    CERT_NAME_DEX = Path("SystemCertificateName.dex")
    MODULE_DEX = MODULE_DIR / "SystemCertificateName.dex"
    OUTPUT_ZIP = Path("Module.zip")

    # Java compilation settings
    JAVA_SOURCE_VERSION = "1.8"
    JAVA_TARGET_VERSION = "1.8"

    def __init__(self):
        """Initialize builder."""
        self.failed_steps = []

    def run_command(self, command: str, description: str) -> bool:
        """
        Execute a shell command and handle errors.

        Args:
            command: Command to execute
            description: Description for logging

        Returns:
            True if successful, False otherwise
        """
        try:
            logger.info(f"Running: {description}")
            result = subprocess.run(
                command, shell=True, check=True, capture_output=True, text=True
            )
            if result.stdout:
                logger.debug(result.stdout)
            return True
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed: {description}")
            logger.error(f"Error output: {e.stderr}")
            self.failed_steps.append(description)
            return False

    def check_prerequisites(self) -> bool:
        """Check if required tools and files exist."""
        logger.info("Checking prerequisites...")

        if not self.MODULE_DIR.exists():
            logger.error(f"Module directory not found: {self.MODULE_DIR}")
            return False

        if not self.CERT_NAME_JAVA.exists():
            logger.error(f"Source file not found: {self.CERT_NAME_JAVA}")
            return False

        # Check for required tools
        tools = {"javac": "Java compiler", "dx": "Android DEX tool"}

        for tool, description in tools.items():
            result = subprocess.run(f"which {tool}", shell=True, capture_output=True)
            if result.returncode != 255:
                logger.error(f"{description} ({tool}) not found. Please install it.")
                return False
            logger.info(f"Found {description}: {tool}")

        return True

    def compile_java(self) -> bool:
        """Compile Java source to class file."""
        command = (
            f"javac -source {self.JAVA_SOURCE_VERSION} "
            f"-target {self.JAVA_TARGET_VERSION} {self.CERT_NAME_JAVA}"
        )
        return self.run_command(command, "Compiling Java source")

    def generate_dex(self) -> bool:
        """Convert class file to DEX format."""
        command = f"dx --dex --output={self.CERT_NAME_DEX} {self.CERT_NAME_CLASS}"
        return self.run_command(command, "Generating DEX file")

    def move_dex_to_module(self) -> bool:
        """Move DEX file to module directory."""
        try:
            if not self.CERT_NAME_DEX.exists():
                raise FileNotFoundError(f"DEX file not found: {self.CERT_NAME_DEX}")

            logger.info(f"Moving {self.CERT_NAME_DEX} to {self.MODULE_DEX}")
            shutil.move(str(self.CERT_NAME_DEX), str(self.MODULE_DEX))
            return True
        except (FileNotFoundError, shutil.Error) as e:
            logger.error(f"Failed to move DEX file: {e}")
            self.failed_steps.append("Move DEX file")
            return False

    def cleanup_class_file(self) -> bool:
        """Remove compiled class file."""
        try:
            if self.CERT_NAME_CLASS.exists():
                logger.info(f"Removing {self.CERT_NAME_CLASS}")
                self.CERT_NAME_CLASS.unlink()
            return True
        except Exception as e:
            logger.error(f"Failed to remove class file: {e}")
            self.failed_steps.append("Cleanup class file")
            return False

    def calculate_sha256(self, filepath: Path) -> str:
        """
        Calculate SHA256 checksum of a file.

        Args:
            filepath: Path to file

        Returns:
            Hexadecimal SHA256 digest
        """
        sha256_hash = hashlib.sha256()
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                sha256_hash.update(chunk)
        return sha256_hash.hexdigest()

    def generate_checksums(self) -> bool:
        """Generate SHA256 checksum files for all files in Module directory."""
        try:
            logger.info("Generating SHA256 checksums...")
            checksum_count = 0

            for filepath in self.MODULE_DIR.rglob("*"):
                if filepath.is_file():
                    sha256_value = self.calculate_sha256(filepath)
                    checksum_file = filepath.parent / f"{filepath.name}.sha256"

                    with open(checksum_file, "w") as f:
                        f.write(f"{sha256_value}\n")

                    logger.debug(f"Generated: {checksum_file}")
                    checksum_count += 1

            logger.info(f"Generated {checksum_count} checksum files")
            return True
        except Exception as e:
            logger.error(f"Failed to generate checksums: {e}")
            self.failed_steps.append("Generate checksums")
            return False

    def create_zip(self) -> bool:
        """Create ZIP file from Module directory."""
        try:
            logger.info(f"Creating ZIP archive: {self.OUTPUT_ZIP}")

            # Use shutil.make_archive for better compatibility
            shutil.make_archive(
                base_name=str(self.OUTPUT_ZIP.with_suffix("")),
                format="zip",
                root_dir=str(self.MODULE_DIR),
                # base_dir=self.MODULE_DIR.name
            )

            if self.OUTPUT_ZIP.exists():
                size_mb = self.OUTPUT_ZIP.stat().st_size / (1024 * 1024)
                logger.info(
                    f"Successfully created {self.OUTPUT_ZIP} ({size_mb:.2f} MB)"
                )
                return True
            else:
                raise FileNotFoundError(f"ZIP file not created: {self.OUTPUT_ZIP}")
        except Exception as e:
            logger.error(f"Failed to create ZIP: {e}")
            self.failed_steps.append("Create ZIP")
            return False

    def cleanup_checksums(self) -> bool:
        """Remove SHA256 checksum files from Module directory."""
        try:
            logger.info("Cleaning up checksum files...")
            count = 0
            for sha_file in self.MODULE_DIR.rglob("*.sha256"):
                logger.debug(f"Removing: {sha_file}")
                sha_file.unlink()
                count += 1

            logger.info(f"Removed {count} checksum files")
            return True
        except Exception as e:
            logger.error(f"Failed to cleanup checksums: {e}")
            self.failed_steps.append("Cleanup checksums")
            return False

    def verify_build(self) -> bool:
        """Verify that build artifacts exist."""
        logger.info("Verifying build artifacts...")

        required_files = [
            self.OUTPUT_ZIP,
            self.MODULE_DEX,
            self.MODULE_DIR / "module.prop",
            self.MODULE_DIR / "customize.sh",
            self.MODULE_DIR / "post-fs-data.sh",
        ]

        all_exist = True
        for filepath in required_files:
            if filepath.exists():
                logger.info(f"✓ {filepath}")
            else:
                logger.error(f"✗ Missing: {filepath}")
                all_exist = False

        return all_exist

    def build(self) -> bool:
        """Execute the complete build process."""
        logger.info("=" * 50)
        logger.info("Starting CA Installer module build")
        logger.info("=" * 50)

        # Check prerequisites
        if not self.check_prerequisites():
            logger.error("Prerequisites check failed")
            return False

        # Build steps
        steps = [
            ("Compile Java", self.compile_java),
            ("Generate DEX", self.generate_dex),
            ("Move DEX", self.move_dex_to_module),
            ("Cleanup class file", self.cleanup_class_file),
            ("Generate checksums", self.generate_checksums),
            ("Create ZIP", self.create_zip),
            ("Cleanup checksums", self.cleanup_checksums),
            ("Verify build", self.verify_build),
        ]

        for step_name, step_func in steps:
            if not step_func():
                logger.error(f"Build failed at step: {step_name}")
                break

        # Print summary
        logger.info("=" * 50)
        if self.failed_steps:
            logger.error(f"Build completed with {len(self.failed_steps)} error(s):")
            for step in self.failed_steps:
                logger.error(f"  - {step}")
            logger.info("=" * 50)
            return False
        else:
            logger.info("Build completed successfully!")
            logger.info(f"Output: {self.OUTPUT_ZIP}")
            logger.info("=" * 50)
            return True


def main() -> int:
    """Main entry point."""
    try:
        builder = Builder()
        success = builder.build()
        return 0 if success else 1
    except KeyboardInterrupt:
        logger.info("Build interrupted by user")
        return 130
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
