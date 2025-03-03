#!/bin/bash
# This script pushes the generated SDK to its repo and creates a PR
set -eo pipefail

ROOT_DIR=$(git rev-parse --show-toplevel)
COMMIT_NAME="SDK Generator Bot"
COMMIT_EMAIL="noreply@stackit.de"
FOLDER_TO_PUSH_PATH="${ROOT_DIR}/sdk" # Comes from generate-sdk.sh
REPO_URL_SSH="git@github.com:stackitcloud/stackit-sdk-go.git"
REPO_BRANCH="main"

if [ $# -ne 4 ]; then
    echo "Not enough arguments supplied. Required: 'branch-name' 'commit-message' 'pr-title' 'pr-body'"
    exit 1
fi

if [ ! -d ${FOLDER_TO_PUSH_PATH} ]; then
    echo "sdk to commit not found in root. Please run make generate-sdk"
    exit 1
fi

# Create temp directory to work on
work_dir=$(mktemp -d)
if [[ ! ${work_dir} || -d {work_dir} ]]; then
    echo "Unable to create temporary directory"
    exit 1
fi

# Delete temp directory on exit
trap "rm -rf ${work_dir}" EXIT

# Where the git repo will be created
mkdir ${work_dir}/git_repo

# Initialize git repo
cd ${work_dir}/git_repo
git init -q
git config user.name "${COMMIT_NAME}"
git config user.email "${COMMIT_EMAIL}"
git remote add origin "${REPO_URL_SSH}"
git pull origin "${REPO_BRANCH}"
git checkout -b "${REPO_BRANCH}" origin/"${REPO_BRANCH}"

# Replace old SDK with new one
# Removal of pulled data is necessary because the old version may have files
# that were deleted in the new version
rm -rf ./*
cp -a ${FOLDER_TO_PUSH_PATH}/. ./

if git diff --exit-code --quiet; then
    echo "SDK is unchanged, nothing to commit."
else
    # Commit and push files
    git switch -c "$1"
    git add -A
    git commit -m "$2"
    git push origin "$1"

    # Create PR
    gh pr create --title "$3" --body "$4" --head "$1" --base "main"
fi
