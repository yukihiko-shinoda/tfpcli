#!/usr/bin/env bash
# Fail fast: without this, a failed download or install still exits 0 and the setup step passes,
# leaving the failure to surface much later as "tenv: command not found" in the tests.
set -euo pipefail

TENV_VERSION=${1:-"v4.14.8"}
BUILDARCH=$(dpkg --print-architecture)

apt-get update
# Git required when download some aws module:
#   Could not download module "s3_bucket"
#   (services/performance_reposync/cloudwatchlogs.tf:11) source code from
#   "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket?ref=v1.22.0":
#   error downloading
#   'https://github.com/terraform-aws-modules/terraform-aws-s3-bucket?ref=v1.22.0':
#   git must be available and on the PATH.
# see:
#   - Module Sources - Terraform by HashiCorp
#     https://www.terraform.io/docs/language/modules/sources.html#generic-git-repository
# No "/stable" release pin: that suite exists only on Debian, so Ubuntu (e.g. GitHub Actions runners)
# rejects it with "Release 'stable' for 'curl' was not found".
apt-get install -y --no-install-recommends \
    curl \
    git \
    libdigest-sha-perl \
    unzip
rm -rf /var/lib/apt/lists/*
DEB_NAME="tenv_${TENV_VERSION}_${BUILDARCH}.deb"
# --fail: don't save an HTTP error page as the .deb; --retry: ride out transient GitHub errors.
CURL=(curl --fail --silent --show-error --location --retry 5 --retry-all-errors)
# Download through the REST API's release asset endpoint rather than
# https://github.com/tofuutils/tenv/releases/download/..., which kept answering 504 for every tenv
# asset (other repositories' release downloads were unaffected).
# - REST API endpoints for release assets - GitHub Docs
#   https://docs.github.com/en/rest/releases/assets#get-a-release-asset
ASSET_URL=$(
    "${CURL[@]}" "https://api.github.com/repos/tofuutils/tenv/releases/tags/${TENV_VERSION}" |
        python3 -c 'import json, sys; print(next(a["url"] for a in json.load(sys.stdin)["assets"] if a["name"] == sys.argv[1]))' "${DEB_NAME}"
)
"${CURL[@]}" --header "Accept: application/octet-stream" --output "${DEB_NAME}" "${ASSET_URL}"
dpkg -i "${DEB_NAME}"
rm "${DEB_NAME}"
tenv completion bash > ~/.tenv.completion.bash
# Reason: To put raw string into ~/.bashrc .
# shellcheck disable=SC2016
echo 'source ${HOME}/.tenv.completion.bash' >> ~/.bashrc
