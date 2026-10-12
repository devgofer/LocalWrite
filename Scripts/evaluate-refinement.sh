#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
evaluation_dir=$(mktemp -d /private/tmp/localwrite-evaluation.XXXXXX)
trap 'rm -rf "$evaluation_dir"' EXIT
xcrun swiftc -parse-as-library -target arm64-apple-macos26.0 \
    Sources/LocalWriteCore/AI/LocalWriteEngine.swift \
    Sources/LocalWriteCore/AI/FoundationModelsEngine.swift \
    Sources/LocalWriteCore/AI/RefinementPolicy.swift \
    Sources/LocalWriteCore/AI/WritingContext.swift \
    Sources/LocalWriteCore/Models/RefinementResult.swift \
    Scripts/EvaluateRefinement.swift -o "$evaluation_dir/evaluate"
"$evaluation_dir/evaluate"
