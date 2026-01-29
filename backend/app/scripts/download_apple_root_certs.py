"""
Download Apple root certificates for IAP Webhook V2 verification.
Run from project root: python -m app.scripts.download_apple_root_certs
"""
import os
import sys

CERT_URLS = [
    ("AppleIncRootCertificate.cer", "https://www.apple.com/appleca/AppleIncRootCertificate.cer"),
    ("AppleRootCA-G2.cer", "https://www.apple.com/certificateauthority/AppleRootCA-G2.cer"),
    ("AppleRootCA-G3.cer", "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer"),
]


def main():
    base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    cert_dir = os.path.join(base, "app", "certs", "apple_root")
    os.makedirs(cert_dir, exist_ok=True)

    try:
        import requests
    except ImportError:
        print("Install requests: pip install requests")
        sys.exit(1)

    for name, url in CERT_URLS:
        path = os.path.join(cert_dir, name)
        if os.path.exists(path):
            print(f"Skip (exists): {name}")
            continue
        try:
            r = requests.get(url, timeout=30)
            r.raise_for_status()
            with open(path, "wb") as f:
                f.write(r.content)
            print(f"Downloaded: {name}")
        except Exception as e:
            print(f"Failed {name}: {e}")
            sys.exit(1)

    print("Done. Certificates in:", cert_dir)


if __name__ == "__main__":
    main()
