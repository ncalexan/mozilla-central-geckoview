#!/bin/sh

set -e

ROOT=http://ftp.mozilla.org/pub/mozilla.org/mobile/nightly/latest-mozilla-central-android
CACHE=cache
STAGE=stage
WORK=work
REPO=m2-repo
VERSION=unknown

mkdir -p $CACHE
pushd $CACHE
# This is a fancy way of downloading fennec-VERSION.multi.android-arm.txt to a
# known location.  It's necessary because the Fennec version rolls forward with
# the trains.  The build id could also be extracted from the fennec-*.json file,
# but that requires downloading a file with a version in its name, and requires
# more work to extract the version.
# See http://stackoverflow.com/a/18107344 and the wget man page.
PATTERN=fennec-*.txt
rm -rf $PATTERN
wget --quiet --recursive --level=1 --no-directories --no-parent --accept "$PATTERN" --timestamping $ROOT/
VERSION=$(head -n 1 $PATTERN)

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

mkdir -p $REPO
cp index.html $REPO
mvn --batch-mode \
    deploy:deploy-file -Durl=file://$REPO \
                       -DrepositoryId=org.mozilla \
                       -Dfile=geckoview.aar \
                       -DgroupId=org.mozilla.geckoview \
                       -DartifactId=library \
                       -Dversion=$VERSION \
                       -Dpackaging=aar
