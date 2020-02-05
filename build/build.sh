bundle exec jekyll build -d /tmp/docs/
bundle exec jekyll build -b /4.1 -d /tmp/docs/4.1

git checkout gh-pages
cp -a /tmp/docs/* .

git commit -m "update public site" -a
git push origin gh-pages
