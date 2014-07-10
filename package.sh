#!/bin/sh

set -e

ROOT=http://ftp.mozilla.org/pub/mozilla.org/mobile/nightly/latest-mozilla-central-android/
CACHE=cache
STAGE=stage
WORK=work

mkdir -p $CACHE
pushd $CACHE
wget --timestamping $ROOT/geckoview_library.zip
wget --timestamping $ROOT/geckoview_assets.zip
popd

rm -rf $WORK
mkdir -p $WORK
pushd $WORK
unzip ../$CACHE/geckoview_library.zip
unzip ../$CACHE/geckoview_assets.zip
popd

# The 'aar' bundle is the binary distribution of an Android Library Project.
#
# The file extension is .aar, and the maven artifact type should be aar as well, but the file itself a simple zip file with the following entries:
#
#     /AndroidManifest.xml (mandatory)
#     /classes.jar (mandatory)
#     /res/ (mandatory)
#     /R.txt (mandatory)
#     /assets/ (optional)
#     /libs/*.jar (optional)
#     /jni/<abi>/*.so (optional)
#     /proguard.txt (optional)
#     /lint.jar (optional)
#
# These entries are directly at the root of the zip file.
#
# The R.txt file is the output of aapt with --output-text-symbols.

rm -rf $STAGE
mkdir -p $STAGE
cp $WORK/geckoview_library/AndroidManifest.xml $STAGE/AndroidManifest.xml

jar cvf $STAGE/classes.jar README.md

cp -R $WORK/geckoview_library/res $STAGE/res
find $STAGE/res -iname '.mkdir.done' | xargs rm

cp -R $WORK/geckoview_library/bin/R.txt $STAGE

mkdir -p $STAGE/libs
cp $WORK/geckoview_library/libs/*.jar $STAGE/libs

# In some brave future world, we'll handle ARMv6, ARMv7, and x86.
mkdir -p $STAGE/jni
cp -R $WORK/geckoview_library/libs/armeabi-v7a $STAGE/jni

# Including the assets/ directory Just Works in gradle.
cp -R $WORK/assets $STAGE/assets

pushd $STAGE
zip ../geckoview.aar -r .
popd

# TODO: Extract this from the build properties JSON.
VERSION=20140710071924

REPO=m2-repo
mkdir -p $REPO

mvn deploy:deploy-file -Durl=file://$REPO \
                       -DrepositoryId=org.mozilla \
                       -Dfile=geckoview.aar \
                       -DgroupId=org.mozilla.geckoview \
                       -DartifactId=library \
                       -Dversion=$VERSION \
                       -Dpackaging=aar
