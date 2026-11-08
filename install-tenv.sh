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
# --fail: don't save an HTTP error page as the .deb; --retry: ride out transient GitHub errors.
curl --fail --silent --show-error --location --retry 5 --retry-all-errors \
    --output "tenv_${TENV_VERSION}_${BUILDARCH}.deb" \
    "https://github.com/tofuutils/tenv/releases/download/${TENV_VERSION}/tenv_${TENV_VERSION}_${BUILDARCH}.deb"
dpkg -i "tenv_${TENV_VERSION}_${BUILDARCH}.deb"
rm "tenv_${TENV_VERSION}_${BUILDARCH}.deb"
tenv completion bash > ~/.tenv.completion.bash
# Reason: To put raw string into ~/.bashrc .
# shellcheck disable=SC2016
echo 'source ${HOME}/.tenv.completion.bash' >> ~/.bashrc
