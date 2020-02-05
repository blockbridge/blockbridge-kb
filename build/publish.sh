#!/bin/bash
set -euo pipefail

SRCDIR=${SRCDIR:-/tmp/srcdir.$$}
DOCDIR=${DOCDIR:-/tmp/docdir.$$}
SITE=${SITE:-/tmp/site}

onexit()
{
    rm -rf $SRCDIR
    rm -rf $DOCDIR
}

trap onexit EXIT

mkdir -p $DOCDIR
chmod 777 $DOCDIR
mkdir -p $SRCDIR/head
cp -a * $SRCDIR/head

bundle exec jekyll build --source $SRCDIR/head --destination $DOCDIR
for version in $(< VERSIONS)
do
    mkdir -p $DOCDIR/$version
    chmod 777 $DOCDIR/$version
    mkdir -p $SRCDIR/$version
    git archive v${version} | tar -x -C $SRCDIR/$version
    bundle exec jekyll build --source $SRCDIR/$version --destination $DOCDIR/$version
done

rm -rf $SITE/*
cp -a $DOCDIR/* $SITE/.
