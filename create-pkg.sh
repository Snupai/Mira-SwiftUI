#!/bin/bash
set -e

APP_NAME="Mira"
IDENTIFIER="com.snupai.mira"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

VERSION=$(grep -m1 'VERSION=' bundle.sh | cut -d'"' -f2)
COMPONENT_PKG="${APP_NAME}-component.pkg"
INSTALLER_PKG="${APP_NAME}-Installer.pkg"
RESOURCES_DIR="installer/resources"

echo "📦 Building ${APP_NAME} pkg v${VERSION}..."

if [ ! -d "${APP_NAME}.app" ]; then
    echo "❌ ${APP_NAME}.app not found! Run bundle.sh first."
    exit 1
fi

pkgbuild \
    --identifier "${IDENTIFIER}" \
    --version "${VERSION}" \
    --install-location "/Applications" \
    --component "${APP_NAME}.app" \
    "${COMPONENT_PKG}"

RESOURCES_FLAG=()
if [ -d "${RESOURCES_DIR}" ]; then
    if compgen -G "${RESOURCES_DIR}/*" > /dev/null; then
        RESOURCES_FLAG=(--resources "${RESOURCES_DIR}")
    fi
fi

productbuild \
    --package "${COMPONENT_PKG}" \
    --identifier "${IDENTIFIER}" \
    --version "${VERSION}" \
    "${RESOURCES_FLAG[@]}" \
    "${INSTALLER_PKG}"

rm -f "${COMPONENT_PKG}"

echo "✅ Created ${INSTALLER_PKG}"
