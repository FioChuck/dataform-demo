#!/usr/bin/env bash
set -euo pipefail

# Required environment variables:
#   PROJECT_ID      - Google Cloud project ID (e.g., cf-data-analytics)
#   REGION          - Google Cloud region (e.g., us-central1)
#   REPOSITORY_ID   - Dataform repository ID (e.g., dataform-demo)
#   RELEASE_CONFIG  - Release config name (e.g., production)

: "${PROJECT_ID:?Environment variable PROJECT_ID is required}"
: "${REGION:?Environment variable REGION is required}"
: "${REPOSITORY_ID:?Environment variable REPOSITORY_ID is required}"
: "${RELEASE_CONFIG:?Environment variable RELEASE_CONFIG is required}"

echo "Compiling Dataform release config: ${RELEASE_CONFIG}"
echo "Repository: projects/${PROJECT_ID}/locations/${REGION}/repositories/${REPOSITORY_ID}"

RELEASE_CONFIG_PATH="projects/${PROJECT_ID}/locations/${REGION}/repositories/${REPOSITORY_ID}/releaseConfigs/${RELEASE_CONFIG}"
API_URL="https://dataform.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/repositories/${REPOSITORY_ID}/compilationResults"

ACCESS_TOKEN=$(gcloud auth print-access-token)
if [ -z "${ACCESS_TOKEN}" ]; then
  echo "::error::Failed to obtain Google Cloud access token."
  exit 1
fi

PAYLOAD=$(jq -n --arg rc "${RELEASE_CONFIG_PATH}" '{releaseConfig: $rc}')

RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" \
  "${API_URL}")

echo "Response from Dataform API:"
echo "${RESPONSE}"

if [ -z "${RESPONSE}" ]; then
  echo "::error::Received empty response from Dataform API."
  exit 1
fi

if echo "${RESPONSE}" | jq -e '.error' > /dev/null 2>&1; then
  echo "::error::Dataform compilation API error: $(echo "${RESPONSE}" | jq -r '.error.message')"
  exit 1
fi

if echo "${RESPONSE}" | jq -e '.compilationErrors and (.compilationErrors | length > 0)' > /dev/null 2>&1; then
  echo "::error::Dataform compilation failed with code errors:"
  echo "${RESPONSE}" | jq -r '.compilationErrors'
  exit 1
fi

COMPILATION_RESULT_NAME=$(echo "${RESPONSE}" | jq -r '.name // empty')
if [ -z "${COMPILATION_RESULT_NAME}" ]; then
  echo "::error::Failed to create compilation result, no resource name returned."
  exit 1
fi

echo "Successfully created compilation result: ${COMPILATION_RESULT_NAME}"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "compilation_result_name=${COMPILATION_RESULT_NAME}" >> "${GITHUB_OUTPUT}"
fi
