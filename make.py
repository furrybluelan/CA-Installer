import hashlib
import os
from pathlib import Path
import subprocess
import shutil
import zipfile

def sha256sum(filepath: Path) -> str:
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

def generate_sha256_files(root: str) -> None:
    root_path = Path(root)
    for filepath in root_path.rglob("*"):  
        if filepath.is_file():
            sha256_value = sha256sum(filepath)
            sha_file = filepath.with_suffix(filepath.suffix + ".sha256")
            with open(sha_file, "w") as f:
                f.write(sha256_value + "\n")
            print(f"make: {sha_file}")

def zip_folder_contents(folder_path: str, zip_path: str) -> None:
    folder_path = os.path.abspath(folder_path)

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(folder_path):
            for file in files:
                abs_file_path = os.path.join(root, file)
                rel_path = os.path.relpath(abs_file_path, folder_path)
                zipf.write(abs_file_path, rel_path)

if __name__ == "__main__":
    folder = Path("Module/")
    subprocess.run("javac -source 1.8 -target 1.8 CertName.java",shell=True)
    subprocess.run("dx --dex --output=CertName.dex CertName.class",shell=True)
    shutil.move("CertName.dex","Module/CertName.dex")
    os.remove('CertName.class')
    generate_sha256_files(folder)
    zip_folder_contents(folder,'Module.zip')
    subprocess.run("rm Module/*.sha256",shell=True)