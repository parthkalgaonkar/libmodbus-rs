#!/bin/bash
set -e

# Branch from which github create the projects page
DOC_BRANCH="gh-pages"
# Should the projects README.md converted into the index.html file?
## If you which so, make sure the system has a working `pandoc` installation!
CREATE_UPDATE_README=true

# Should the orginal libmodbus documentation build?
BUILD_LIBMODBUS_DOC=true

[[ "$(git symbolic-ref --short HEAD)" == "master" ]] || exit 0

msg() {
    echo "[1;34m> [1;32m$@[0m"
}

dir="$(pwd)"
last_rev="$(git rev-parse HEAD)"
last_msg="$(git log -1 --pretty=%B)"

unset GIT_WORK_TREE

msg "Cloning into a temporary directory..."
# The second call is to support OSX.
tmp="$(mktemp -d 2>/dev/null || mktemp -d -t 'tmp-rust-docs')"
trap "cd \"$dir\"; rm -rf \"$tmp\"" EXIT
git clone -qb master "$dir" "$tmp"

cd "$tmp"
ln -s "$dir/target" "$tmp/target"

msg "Generating documentation..."
cargo doc

if "$BUILD_LIBMODBUS_DOC"; then
  cd libmodbus-sys/libmodbus/doc
  make htmldoc
fi

# Switch to pages
msg "Replacing documentation..."

# Only if $DOC_BRANCH not exists
if ! git checkout -q "$DOC_BRANCH" 2>/dev/null; then
    git checkout -q --orphan "$DOC_BRANCH"
    git rm -q --ignore-unmatch -rf .
    cat > .gitignore <<EOF
target
Cargo.lock
EOF
    git add .gitignore
    git commit -m "Initial commit."
fi


# Clean
git rm -q --ignore-unmatch -rf .


# index.html patch.
## If a index.html exist, update it. Here i use `pandoc`, modify this for your needs.
if "$CREATE_UPDATE_README"; then
  msg "Create or update index.html with the content or the projects README.md"
  git checkout master README.md
  git checkout master share/pandoc.css
  pandoc --css share/pandoc.css --self-contained --highlight-style=tango -s -f markdown -t html5 -o index.html README.md
  git add index.html
  rm -r share
  rm README.md
fi

# Restore gitignore
git reset -q -- .gitignore
git checkout -q -- .gitignore

# Copy documentation into root
cp -a target/doc/* .

if $BUILD_LIBMODBUS_DOC; then
  mkdir libmodbus
  cp libmodbus-sys/libmodbus/doc/*.html libmodbus/
fi

# Remove unneeded files
rm target

# Add all (new) files to git and commit them.
git add .
git commit -m "Update docs for $last_rev" -m "$last_msg"
#git push -qu origin "$DOC_BRANCH"
#git push --set-upstream origin gh-pages

cd $dir
git push --set-upstream origin gh-pages


msg "Done."
