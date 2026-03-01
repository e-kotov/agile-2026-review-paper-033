import urllib.request
import json
import os
import sys
import zipfile
import shutil

def download_figshare(article_id, target_dir):
    base_url = "https://api.figshare.com/v2"
    print(f"--- Figshare Downloader ---")
    print(f"Article ID: {article_id}")
    print(f"Target Dir: {target_dir}")

    # 1. Get file list
    api_url = f"{base_url}/articles/{article_id}/files"
    try:
        with urllib.request.urlopen(api_url) as response:
            files = json.loads(response.read().decode())
    except Exception as e:
        print(f"Error fetching metadata: {e}")
        sys.exit(1)

    if not os.path.exists(target_dir):
        os.makedirs(target_dir)

    for f in files:
        name = f['name']
        download_url = f['download_url']
        dest_path = os.path.join(target_dir, name)

        print(f"Downloading {name}...")
        try:
            with urllib.request.urlopen(download_url) as response, open(dest_path, 'wb') as out_file:
                shutil.copyfileobj(response, out_file)
        except Exception as e:
            print(f"Error downloading {name}: {e}")
            sys.exit(1)

        # 2. Unzip if it's a zip file
        if name.endswith('.zip'):
            print(f"Extracting {name}...")
            try:
                with zipfile.ZipFile(dest_path, 'r') as zip_ref:
                    zip_ref.extractall(target_dir)
                # Optional: remove zip after extraction to save space
                # os.remove(dest_path)
            except Exception as e:
                print(f"Error extracting {name}: {e}")
                sys.exit(1)

    print("Download and preparation complete.")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 download_and_prep.py <article_id> <target_dir>")
        sys.exit(1)
    download_figshare(sys.argv[1], sys.argv[2])
