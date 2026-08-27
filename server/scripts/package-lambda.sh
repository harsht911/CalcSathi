#!/usr/bin/env bash
set -euo pipefail

# Builds server/lambda-deploy.zip — a clean, production-only bundle ready to
# upload directly as this Lambda function's code in the AWS console
# (Runtime: Node.js 20.x, Handler: src/lambda.handler).
#
# Builds in a throwaway temp directory and runs `npm ci --omit=dev` there,
# so it never touches the node_modules used for local dev/testing (which
# still has eslint etc. installed) and never bundles devDependencies into
# the deployed function.
#
# Usage: npm run package:lambda   (from server/), or run this script directly.

cd "$(dirname "$0")/.."
SERVER_DIR="$(pwd)"

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

cp -R src package.json package-lock.json "$BUILD_DIR/"
(cd "$BUILD_DIR" && npm ci --omit=dev --ignore-scripts)

rm -f "$SERVER_DIR/lambda-deploy.zip"
(cd "$BUILD_DIR" && zip -rq "$SERVER_DIR/lambda-deploy.zip" .)

echo "Built server/lambda-deploy.zip ($(du -h "$SERVER_DIR/lambda-deploy.zip" | cut -f1))"
echo "Upload this file directly in the Lambda console (Code -> Upload from -> .zip file)."
