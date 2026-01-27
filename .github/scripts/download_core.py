#!/usr/bin/env python3
import os
import sys
import json
import urllib.request
import shutil
import zipfile
import tarfile
import hashlib

REPO_API = 'https://api.github.com/repos/TrustTunnel/TrustTunnelClient/releases/latest'

def find_asset(assets, platform_keyword, arch_candidates):
    p = platform_keyword.lower()
    archs = [a.lower() for a in arch_candidates]
    for a in assets:
        name = a.get('name','').lower()
        if p in name and any(arch in name for arch in archs):
            return a
    for a in assets:
        name = a.get('name','').lower()
        if p in name:
            return a
    return None

def verify_checksum(file_path, checksum_url):
    print(f'Verifying checksum using {checksum_url}...')
    req = urllib.request.Request(checksum_url, headers={'User-Agent': 'github-actions-script'})
    with urllib.request.urlopen(req) as r:
        remote_checksum_data = r.read().decode('utf-8').strip().split()
        expected_hash = remote_checksum_data[0]

    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    
    actual_hash = sha256_hash.hexdigest()
    if actual_hash.lower() == expected_hash.lower():
        print('Checksum verified successfully.')
        return True
    else:
        print(f'Checksum mismatch! Expected: {expected_hash}, Actual: {actual_hash}')
        return False

def download_url(url, out_path):
    print('Downloading', url)
    req = urllib.request.Request(url, headers={'User-Agent': 'github-actions-script'})
    with urllib.request.urlopen(req) as r, open(out_path, 'wb') as f:
        shutil.copyfileobj(r, f)

def main():
    if len(sys.argv) < 2:
        print('Usage: download_core.py <platform>')
        sys.exit(2)

    platform = sys.argv[1].lower()
    if platform not in ('windows','linux'):
        print('Invalid platform', platform)
        sys.exit(2)

    print('Querying latest release for TrustTunnelCore...')
    headers = {'User-Agent': 'github-actions-script', 'Accept': 'application/vnd.github+json'}
    token = os.environ.get('GITHUB_TOKEN')
    if token:
        headers['Authorization'] = f'token {token}'
    
    req = urllib.request.Request(REPO_API, headers=headers)
    with urllib.request.urlopen(req) as r:
        data = json.load(r)

    assets = data.get('assets', [])
    if not assets:
        print('No assets found')
        sys.exit(1)

    if platform == 'windows':
        arch_candidates = ['x86_64','amd64', 'win64']
        platform_keyword = 'windows'
    else:
        arch_candidates = [ 'x86_64','amd64']
        platform_keyword = 'linux'

    asset = find_asset(assets, platform_keyword, arch_candidates)
    if not asset:
        print(f'No matching asset for {platform}')
        sys.exit(1)

   
    checksum_asset = None
    for a in assets:
        if a['name'].startswith(asset['name']) and (a['name'].endswith('.sha256') or a['name'].endswith('.checksum')):
            checksum_asset = a
            break

    os.makedirs('assets/core', exist_ok=True)
    out_file = os.path.join('assets/core', asset['name'])
    download_url(asset['browser_download_url'], out_file)


    if checksum_asset:
        if not verify_checksum(out_file, checksum_asset['browser_download_url']):
            sys.exit(1)
    else:
        print('Warning: No checksum asset found, skipping verification.')


    extract_path = 'assets/core'
    try:
        if zipfile.is_zipfile(out_file):
            with zipfile.ZipFile(out_file, 'r') as z:
                z.extractall(extract_path)
        elif tarfile.is_tarfile(out_file):
            with tarfile.open(out_file, 'r:*') as t:
                t.extractall(extract_path)
        else:
            shutil.unpack_archive(out_file, extract_path)
        
        os.remove(out_file)


        content = [n for n in os.listdir(extract_path) if not n.startswith('.')]
        if len(content) == 1:
            inner_path = os.path.join(extract_path, content[0])
            if os.path.isdir(inner_path):
                print(f"Flattening directory: {content[0]}")
                for item in os.listdir(inner_path):
                    shutil.move(os.path.join(inner_path, item), extract_path)
                os.rmdir(inner_path)


        if platform == 'linux':
            for root, _, files in os.walk(extract_path):
                for f in files:
                    f_path = os.path.join(root, f)
                    os.chmod(f_path, os.stat(f_path).st_mode | 0o111)

    except Exception as e:
        print(f'Error processing archive: {e}')
        sys.exit(1)

    for root, _, files in os.walk(extract_path):
        for f in files:
            print('READY:', os.path.join(root, f))

if __name__ == '__main__':
    main()