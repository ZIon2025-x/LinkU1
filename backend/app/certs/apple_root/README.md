# Apple Root Certificates for IAP Webhook Verification

App Store Server Notifications V2 signature verification requires Apple root certificates.

## Download

1. Download these certificates from [Apple PKI](https://www.apple.com/certificateauthority/):
   - [Apple Inc. Root](https://www.apple.com/appleca/AppleIncRootCertificate.cer)
   - [Apple Root CA - G2](https://www.apple.com/certificateauthority/AppleRootCA-G2.cer)
   - [Apple Root CA - G3](https://www.apple.com/certificateauthority/AppleRootCA-G3.cer)

2. Place the `.cer` files in this directory.

Or run the download script (from backend root):

```bash
python -m app.scripts.download_apple_root_certs
```

## Environment

- `APPLE_ROOT_CERT_DIR`: Override path to directory containing the root certs (default: this directory).
