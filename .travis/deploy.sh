#!/bin/bash
set -e # Exit with nonzero exit code if anything fails
MY_PATH="`dirname \"$0\"`"
MY_CWD=$(pwd)
ENCRYPTION_LABEL=e1304e2fcacf

function doCompile {
    ./MakeUpd.sh
}

# Pull requests shouldn't try to deploy, just build to verify
# Only for one branch: -o "$TRAVIS_BRANCH" != "develop"
if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
    echo "Skipping deploy $TRAVIS_PULL_REQUEST $TRAVIS_BRANCH."
    exit 0
fi

# Save some useful information
REPO=`git config remote.origin.url`
SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}
SHA=`git rev-parse --verify HEAD`

# Run our compile script
doCompile

# Now let's go have some fun with the cloned repo
git config user.name "Travis CI"
git config user.email "$COMMIT_AUTHOR_EMAIL"

git clone $REPO $MY_CWD/out
cd $MY_CWD/out
git checkout gh-pages

if diff $MY_CWD/controls_mobilealerts.txt repository/$TRAVIS_BRANCH/controls_mobilealerts.txt; then
    echo "No changes to the output $MY_CWD/controls_mobilealerts.txt repository/$TRAVIS_BRANCH/controls_mobilealerts.txt on this push; exiting."
    exit 0
fi

mkdir -p repository/$TRAVIS_BRANCH/FHEM
mv $MY_CWD/controls_mobilealerts.txt repository/$TRAVIS_BRANCH/controls_mobilealerts.txt
cp $MY_CWD/CHANGED repository/$TRAVIS_BRANCH/CHANGED
cp $MY_CWD/FHEM/* repository/$TRAVIS_BRANCH/FHEM/.

# Commit the "changes", i.e. the new version.
# The delta will show diffs between new and old versions.
git add -v -A
git commit -v -m "Travis build $TRAVIS_BUILD_NUMBER update Controlfile"

# Get the deploy key by using Travis's stored variables to decrypt deploy_key.enc
ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}
openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IV -in $MY_CWD/.travis/travis_id_rsa.enc -out $MY_CWD/.travis/travis_id_rsa -d
chmod 600 $MY_CWD/.travis/travis_id_rsa
eval `ssh-agent -s`
ssh-add $MY_CWD/.travis/travis_id_rsa

# Now that we're all set up, we can push.
git push -v $SSH_REPO gh-pages

cd $MY_CWD
