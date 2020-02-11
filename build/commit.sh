#!/bin/bash

. $(git --exec-path)/git-sh-setup
require_clean_work_tree "update static site"

set -euo pipefail
cbranch=$(git symbolic-ref --short HEAD)

git checkout -b gh-pages || true
cp -r _site/* .
git add .
git diff --cached --quiet --exit-code || git commit -m "update static site"
git checkout $cbranch
