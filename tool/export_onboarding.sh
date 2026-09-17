#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export GETPRIO_SCREENSHOT_DIR="${GETPRIO_SCREENSHOT_DIR:-$(pwd)/../_materials/onboarding-slides}"
flutter test tool/export_onboarding_test.dart --run-skipped
# App Store Connect rejects PNG alpha channels, even when every pixel is opaque.
python3 - <<'PY'
import os
from pathlib import Path
from PIL import Image
root = Path(os.environ['GETPRIO_SCREENSHOT_DIR'])
for prefix, size in [('iphone-6.9', (1320, 2868)), ('ipad-13', (2064, 2752))]:
    files = sorted(root.glob(f'{prefix}-0[123]-*.png'))
    assert len(files) == 3, (prefix, len(files))
    for path in files:
        with Image.open(path) as source:
            assert source.size == size, (path, source.size)
            image = source.convert('RGB')
        image.save(path, format='PNG', optimize=True)
        print(path.name, image.size, image.mode)
PY
