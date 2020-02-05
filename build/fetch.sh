git fetch
for b in `git branch -r | grep -v -- '->'`; do git branch --track ${b##origin/} $b; done || true
