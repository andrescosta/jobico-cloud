#!/bin/bash

# Configuration
REGISTRY="https://reg.jobico.local/v2"
CREDS="jobico:jobico123"
CURL_OPTS="-sk --user $CREDS"

# 1. Fetch the list of repositories
REPOS=$(curl $CURL_OPTS "$REGISTRY/_catalog" | jq -r '.repositories[]')

if [ -z "$REPOS" ]; then
    echo "No repositories found or authentication failed."
    exit 1
fi

echo "Connected to $REGISTRY"
echo "--------------------------------"

# 2. Loop through each image and list its tags
for REPO in $REPOS; do
    # Fetch the tags for the current repository
    TAG_DATA=$(curl $CURL_OPTS "$REGISTRY/$REPO/tags/list")
    
    # Extract tags using jq; handle cases where 'tags' might be null
    TAGS=$(echo "$TAG_DATA" | jq -r '.tags[]? // "no tags found"')

    echo "IMAGE: $REPO"
    
    for TAG in $TAGS; do
        echo "  └── tag: $TAG"
    done
    echo ""
done
