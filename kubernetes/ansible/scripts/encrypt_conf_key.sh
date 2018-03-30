#!/bin/bash

cd $INSTALL_DIR

# Generate an encryption key

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

# Create the encryption-config.yaml encryption config file

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
