#!/usr/bin/env bash
#
# upload_dag.sh - Upload and update DAG(s) in Google Cloud Composer
#
# Usage:
#   ./upload_dag.sh [DAG_FILE]
#   ./upload_dag.sh --file dags/orchestration.py
#   ./upload_dag.sh --all
#

set -euo pipefail

# Default configuration (can be overridden via environment variables or flags)
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || echo "cf-data-analytics")}"
LOCATION="${LOCATION:-$(gcloud config get-value compute/region 2>/dev/null || echo "us-central1")}"
COMPOSER_ENVIRONMENT="${COMPOSER_ENVIRONMENT:-etl-orchestration}"
DEFAULT_DAG="dags/orchestration.py"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [DAG_FILE]

Uploads and updates Airflow DAG files in Cloud Composer.

Arguments:
  DAG_FILE                      Path to the DAG file to upload (default: ${DEFAULT_DAG})

Options:
  -f, --file PATH               Path to the DAG file to upload
  -a, --all                     Upload all DAG files in the dags/ directory
  -e, --environment NAME        Cloud Composer environment name (default: ${COMPOSER_ENVIRONMENT})
  -l, --location REGION         GCP region for Composer (default: ${LOCATION})
  -p, --project PROJECT_ID      Google Cloud project ID (default: ${PROJECT_ID})
  -h, --help                    Show this help message and exit

Examples:
  $(basename "$0")                              # Upload default dags/orchestration.py
  $(basename "$0") dags/orchestration.py        # Upload specific DAG
  $(basename "$0") --all                        # Upload all DAGs
EOF
  exit 0
}

# Parse options
ALL_DAGS=false
TARGET_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    -a|--all)
      ALL_DAGS=true
      shift
      ;;
    -f|--file)
      TARGET_FILE="$2"
      shift 2
      ;;
    -e|--environment)
      COMPOSER_ENVIRONMENT="$2"
      shift 2
      ;;
    -l|--location)
      LOCATION="$2"
      shift 2
      ;;
    -p|--project)
      PROJECT_ID="$2"
      shift 2
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      usage
      ;;
    *)
      if [[ -z "${TARGET_FILE}" ]]; then
        TARGET_FILE="$1"
      else
        echo "Error: Multiple DAG files specified: ${TARGET_FILE} and $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

echo "=================================================="
echo " Cloud Composer DAG Deployment"
echo "=================================================="
echo "Project:      ${PROJECT_ID}"
echo "Location:     ${LOCATION}"
echo "Environment:  ${COMPOSER_ENVIRONMENT}"
echo "--------------------------------------------------"

if [ "${ALL_DAGS}" = true ]; then
  if [ ! -d "dags" ]; then
    echo "Error: 'dags' directory not found in ${SCRIPT_DIR}" >&2
    exit 1
  fi
  echo "Uploading all DAGs from dags/ directory..."
  gcloud composer environments storage dags import \
    --project="${PROJECT_ID}" \
    --environment="${COMPOSER_ENVIRONMENT}" \
    --location="${LOCATION}" \
    --source="dags"
  echo "Listing DAGs in environment storage:"
  gcloud composer environments storage dags list \
    --project="${PROJECT_ID}" \
    --environment="${COMPOSER_ENVIRONMENT}" \
    --location="${LOCATION}"
else
  TARGET_FILE="${TARGET_FILE:-${DEFAULT_DAG}}"
  if [ ! -f "${TARGET_FILE}" ]; then
    echo "Error: File '${TARGET_FILE}' not found." >&2
    exit 1
  fi

  echo "Uploading DAG file: ${TARGET_FILE}"
  gcloud composer environments storage dags import \
    --project="${PROJECT_ID}" \
    --environment="${COMPOSER_ENVIRONMENT}" \
    --location="${LOCATION}" \
    --source="${TARGET_FILE}"

  FILENAME="$(basename "${TARGET_FILE}")"
  echo "Verifying upload in Composer storage..."
  gcloud composer environments storage dags list \
    --project="${PROJECT_ID}" \
    --environment="${COMPOSER_ENVIRONMENT}" \
    --location="${LOCATION}" \
    --prefix="dags/${FILENAME}" 2>/dev/null || true
fi

echo "=================================================="
echo " DAG upload complete!"
echo " Airflow will parse the updated DAG within 1-2 minutes."
echo "=================================================="
