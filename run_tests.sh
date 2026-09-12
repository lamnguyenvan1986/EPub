#!/bin/bash

echo "========================================"
echo "LibriAudio - Complete Test Suite"
echo "========================================"
echo ""

# Colors
GREEN='[0;32m'
RED='[0;31m'
YELLOW='[1;33m'
NC='[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

run_test() {
    echo -e "${YELLOW}Running: $1${NC}"
    $2
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ PASSED: $1${NC}"
        ((PASS_COUNT++))
    else
        echo -e "${RED}❌ FAILED: $1${NC}"
        ((FAIL_COUNT++))
    fi
    echo ""
}

echo "[STAGE 1] Dependencies Check"
echo "----------------------------"
run_test "Install Flutter dependencies" "flutter pub get"

echo ""
echo "[STAGE 2] Static Analysis"
echo "----------------------------"
run_test "Run Dart analyze" "flutter analyze"

echo ""
echo "[STAGE 3] Unit Tests"
echo "----------------------------"
run_test "Run models unit tests" "flutter test test/models_test.dart"

echo ""
echo "[STAGE 4] Feature Tests"
echo "----------------------------"
run_test "Run feature tests" "flutter test test/features_test.dart"

echo ""
echo "[STAGE 5] Build Tests"
echo "----------------------------"
run_test "Build Android APK (debug)" "flutter build apk --debug"
run_test "Build iOS (debug, no codesign)" "flutter build ios --debug --no-codesign"

echo ""
echo "[STAGE 6] Code Quality"
echo "----------------------------"
run_test "Run Dart format check" "dart format --set-exit-if-changed lib/"

echo ""
echo "[STAGE 7] Linting"
echo "----------------------------"
run_test "Run Flutter lints" "flutter pub run flutter_lints ."

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
echo -e "${RED}Failed: $FAIL_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests PASSED!${NC}"
    exit 0
else
    echo -e "${RED}⚠️ Some tests FAILED!${NC}"
    exit 1
fi
