SITE ?= /site

all: serve

serve:
	@mkdir -p _site
	@docker-compose up

fetch:
	@build/fetch.sh

publish: fetch
	docker build -f Dockerfile.publish -t blockbridge-kb:build .
	@sudo rm -rf _site
	@mkdir -p _site
	docker run -u $(shell id -u):$(shell id -g) -i -e SITE=$(SITE) -v $(PWD):/src -v $(PWD)/_site:/site blockbridge-kb:build
	@echo site published to _site

commit:
	@build/commit.sh

push:
	git push origin gh-pages
