#!/usr/bin/env python3
import os
import sys
import json
import urllib.request
import shutil
import zipfile
import tarfile

REPO_API = 'https://api.github.com/repos/TrustTunnel/TrustTunnelClient/releases/latest'

def find_asset(assets, platform_keyword, arch_candidates):
    p = platform_keyword.lower()
    archs = [a.lower() for a in arch_candidates]
    for a in assets:
        name = a.get('name','').lower()
        # require platform keyword and any matching arch token
        if p in name and any(arch in name for arch in archs):
            return a
    # fallback: try platform only
    for a in assets:
        name = a.get('name','').lower()
        if p in name:
            return a
    return None

def download_url(url, out_path):
    print('Downloading', url)
    req = urllib.request.Request(url, headers={'User-Agent': 'github-actions-script'})
    with urllib.request.urlopen(req) as r, open(out_path, 'wb') as f:
        shutil.copyfileobj(r, f)

def main():
    if len(sys.argv) < 2:
        print('Usage: download_core.py <platform>')
        print('platform: windows|linux')
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
        print('No assets found in latest release')
        sys.exit(1)

    if platform == 'windows':
        arch_candidates = ['amd64', 'x86_64', 'x86-64', 'x86', 'win64']
        platform_keyword = 'windows'
    else:
        arch_candidates = ['amd64', 'x86_64', 'x86-64', 'x86']
        platform_keyword = 'linux'

    asset = find_asset(assets, platform_keyword, arch_candidates)
    if not asset:
        print('No matching asset found for', platform)
        print('Available assets:')
        for a in assets:
            print(' -', a.get('name'))
        sys.exit(1)

    print('Selected asset:', asset.get('name'))
    url = asset.get('browser_download_url')
    if not url:
        print('Asset missing browser_download_url')
        sys.exit(1)

    os.makedirs('assets/core', exist_ok=True)
    # Preserve original filename so shutil.unpack_archive can detect format
    filename = os.path.basename(url)
    out_file = os.path.join('assets/core', filename)
    download_url(url, out_file)

    # Try to unpack into assets/core
    try:
        if zipfile.is_zipfile(out_file):
            with zipfile.ZipFile(out_file, 'r') as z:
                z.extractall('assets/core')
            print('Unzipped to assets/core')
            try:
                os.remove(out_file)
                print('Removed archive', out_file)
            except Exception:
                pass
        elif tarfile.is_tarfile(out_file):
            with tarfile.open(out_file, 'r:*') as t:
                t.extractall('assets/core')
            print('Untarred to assets/core')
            try:
                os.remove(out_file)
                print('Removed archive', out_file)
            except Exception:
                pass
        else:
            # fallback to shutil.unpack_archive which relies on filename extension
            try:
                shutil.unpack_archive(out_file, 'assets/core')
                print('Unpacked to assets/core')
            except Exception as e:
                print('Could not unpack archive:', e)
                print('Saved raw asset to', out_file)

    except Exception as e:
        print('Error while unpacking:', e)

    # Log extracted files
    for root, dirs, files in os.walk('assets/core'):
        for f in files:
            print('EXTRACTED:', os.path.join(root, f))

if __name__ == '__main__':
    main()
