#!/bin/bash
# Secure build script for TunisGO
# Usage: ./scripts/secure_build.sh [apk|ipa|appbundle]

set -e

# Check for required environment variables
if [ -z "$INSFORGE_URL" ]; then
    echo "❌ Error: INSFORGE_URL environment variable is not set"
    exit 1
fi

if [ -z "$INSFORGE_ANON_KEY" ]; then
    echo "❌ Error: INSFORGE_ANON_KEY environment variable is not set"
    exit 1
fi

BUILD_TYPE="${1:-apk}"

echo "🔒 Building TunisGO with secure configuration..."
echo "   Build type: $BUILD_TYPE"

case $BUILD_TYPE in
    apk)
        flutter build apk --release \
            --dart-define=INSFORGE_URL="$INSFORGE_URL" \
            --dart-define=INSFORGE_ANON_KEY="$INSFORGE_ANON_KEY"
        echo "✅ APK built successfully!"
        echo "   Output: build/app/outputs/flutter-apk/app-release.apk"
        ;;
    appbundle)
        flutter build appbundle --release \
            --dart-define=INSFORGE_URL="$INSFORGE_URL" \
            --dart-define=INSFORGE_ANON_KEY="$INSFORGE_ANON_KEY"
        echo "✅ App Bundle built successfully!"
        echo "   Output: build/app/outputs/bundle/release/app-release.aab"
        ;;
    ipa)
        flutter build ipa --release \
            --dart-define=INSFORGE_URL="$INSFORGE_URL" \
            --dart-define=INSFORGE_ANON_KEY="$INSFORGE_ANON_KEY"
        echo "✅ IPA built successfully!"
        ;;
    *)
        echo "❌ Unknown build type: $BUILD_TYPE"
        echo "   Valid options: apk, appbundle, ipa"
        exit 1
        ;;
esac
