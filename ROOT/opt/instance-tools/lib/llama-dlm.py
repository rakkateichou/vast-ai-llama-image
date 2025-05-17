import argparse
from huggingface_hub import hf_hub_download
from huggingface_hub.utils import logging
import time
from requests.exceptions import ChunkedEncodingError

def download_with_retries(repo_id, filename, local_dir, max_retries=5, initial_delay=1):
    for attempt in range(max_retries):
        try:
            return hf_hub_download(
                repo_id=repo_id,
                filename=filename,
                local_dir=local_dir,
            )
        except ChunkedEncodingError as e:
            if attempt == max_retries - 1:
                raise
            delay = initial_delay * (2 ** attempt)  # Exponential backoff
            print(f"\nDownload interrupted. Retrying in {delay} seconds... (Attempt {attempt + 1}/{max_retries})", file=sys.stderr)
            time.sleep(delay)

def main():
    parser = argparse.ArgumentParser(description='Download models from Hugging Face Hub')
    parser.add_argument('--repo', required=True, help='Hugging Face repository ID')
    parser.add_argument('--filename', required=True, help='Filename to download')
    
    args = parser.parse_args()
    
    # Enable verbose logging
    logging.set_verbosity_info()
    
    file_path = download_with_retries(
        repo_id=args.repo,
        filename=args.filename,
        local_dir="/workspace/llama.cpp/models",
    )

    print(file_path)

if __name__ == "__main__":
    main()