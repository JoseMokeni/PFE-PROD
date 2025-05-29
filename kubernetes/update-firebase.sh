#!/bin/bash

# Script to update Firebase service account in Kubernetes Secret

FIREBASE_JSON_PATH="./docker/firebase/service-account.json"
SECRET_FILE="./kubernetes/firebase-secret.yaml"

if [ ! -f "$FIREBASE_JSON_PATH" ]; then
    echo "Error: Firebase service account file not found at $FIREBASE_JSON_PATH"
    echo "Please place your Firebase service account JSON file at $FIREBASE_JSON_PATH"
    exit 1
fi

echo "Updating Firebase Secret with actual service account..."

# Encode the JSON file to base64
ENCODED_JSON=$(base64 -w 0 "$FIREBASE_JSON_PATH")

# Create the Secret YAML file
cat > "$SECRET_FILE" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: firebase-secret
type: Opaque
data:
  service-account.json: $ENCODED_JSON
EOF

echo "Firebase Secret updated successfully!"
echo ""
echo "To apply the changes to your cluster, run:"
echo "kubectl apply -f $SECRET_FILE"
echo ""
echo "Or run the full deployment:"
echo "./deploy.sh"
