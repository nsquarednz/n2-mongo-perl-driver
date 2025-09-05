#!/bin/bash
#
# Script to create an RPM package from the N2 Mongo Perl Driver 2.2.2 source files.
VERSION=$1
RELEASE=$2

set -e

function usage {
    echo " "
    echo "usage: $0 <version> [release]"
    echo " "
    echo "  e.g. $0 2.2.2 1"
    echo "  Version must be X.Y with optional .Z"
    echo "  Release must be number, default = 1"
    exit 1
}

# Check validity of version numbers.
if [[ -z "$RELEASE" ]]; then RELEASE=1; fi
if [[ ! $VERSION =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || [[ ! $RELEASE =~ ^[0-9]+$ ]]; then
    usage
fi

# Define our base package name. From there we will add some versoning information as required.
MONGO_PERL_DRIVER_PACKAGE="n2-mongo-perl-driver"
DATE=`date -R`
YEAR=`date '+%Y'`
TAR_MONGO_PERL_DRIVER_PACKAGE=${MONGO_PERL_DRIVER_PACKAGE}_$VERSION.orig.tar.gz

OUR_DIR=`pwd`
BASEPATH=`dirname "$OUR_DIR"`
BASEDIR=`basename "$BASEPATH"`

SRC_DIR=..
DEPLOY_DIR=../deploy

################################################################################
# Clean up.
echo "# Cleaning up"
./clean.sh

################################################################################
# Create the package distribution setup
rm -rf $DEPLOY_DIR
mkdir $DEPLOY_DIR

# Firstly the base service package.
echo "# Building base package directory to $DEPLOY_DIR/$MONGO_PERL_DRIVER_PACKAGE"
cd "$OUR_DIR"
mkdir $DEPLOY_DIR/$MONGO_PERL_DRIVER_PACKAGE

# Build the source files for the Mongo Perl Driver module.
echo "# Compiling: N2 Mongo Perl Driver Module"
cd "$OUR_DIR/$SRC_DIR/"
perl Makefile.PL

# Perform the make task to generate the built files storing them in a structure that can be
# bundled in our Deb and RPM files.
make
make DESTDIR=$OUR_DIR/$DEPLOY_DIR/$MONGO_PERL_DRIVER_PACKAGE/ install

# Just building a .deb at this stage.
# Determine the OS release.
if [ -f "/etc/debian_version" ]; then
    cd "$OUR_DIR";
    rm $DEPLOY_DIR/$MONGO_PERL_DRIVER_PACKAGE/usr/local/lib/x86_64-linux-gnu/perl/*/perllocal.pod

    # Create debian packaging.
    echo "# Building Debian package"
    DEBIAN_VERSION="deb"`lsb_release -sr`

    # Build the Debian package
    # COPY THE DEBIAN PACKAGE TEMPLATE.
    #
    # Template was originally created with:
    #   cd $PACKAGE-$VERSION
    #   dh_make -e $PACKAGE@nsquared.nz
    #
    # (But has been customized since then)
    #
    echo "Building debian package in $MONGO_PERL_DRIVER_PACKAGE-$VERSION/debian"
    mkdir -p $MONGO_PERL_DRIVER_PACKAGE-$VERSION/debian
    find template-n2-mongo-perl-driver -maxdepth 1 -type f -exec cp {} $MONGO_PERL_DRIVER_PACKAGE-$VERSION/debian/ \;

    # MODIFY TEMPLATE DEFAULTS
    perl -pi -e "s/VERSION/$VERSION/g" $MONGO_PERL_DRIVER_PACKAGE-$VERSION/debian/changelog
    perl -pi -e "s/RELEASE/$RELEASE/g" $MONGO_PERL_DRIVER_PACKAGE-$VERSION/debian/changelog
    perl -pi -e "s/DATE/$DATE/g" $MONGO_PERL_DRIVER_PACKAGE-$VERSION/debian/changelog
    perl -pi -e "s/PACKAGE/$MONGO_PERL_DRIVER_PACKAGE/g" $MONGO_PERL_DRIVER_PACKAGE-$VERSION/debian/changelog
    perl -pi -e "s/PACKAGE/$MONGO_PERL_DRIVER_PACKAGE/g" $MONGO_PERL_DRIVER_PACKAGE-$VERSION/debian/control
    perl -pi -e "s/DATE/$DATE/g" $MONGO_PERL_DRIVER_PACKAGE-$VERSION/debian/copyright
    perl -pi -e "s/YEAR/$YEAR/g" $MONGO_PERL_DRIVER_PACKAGE-$VERSION/debian/copyright
    perl -pi -e "s/PACKAGE/$MONGO_PERL_DRIVER_PACKAGE/g" $MONGO_PERL_DRIVER_PACKAGE-$VERSION/debian/$MONGO_PERL_DRIVER_PACKAGE.install
    perl -pi -e "s/PACKAGE/$MONGO_PERL_DRIVER_PACKAGE/g" $MONGO_PERL_DRIVER_PACKAGE-$VERSION/debian/postinst

    # BUILD THE SOURCE TARBALLs that debian needs to build its packages.
    TAR_MONGO_PERL_DRIVER_PACKAGE=${MONGO_PERL_DRIVER_PACKAGE}_$DEBIAN_VERSION_$VERSION.orig.tar.gz

    tar zcf $TAR_MONGO_PERL_DRIVER_PACKAGE $DEPLOY_DIR/$MONGO_PERL_DRIVER_PACKAGE \
        --transform "s#deploy/$MONGO_PERL_DRIVER_PACKAGE#$MONGO_PERL_DRIVER_PACKAGE-$VERSION#"
    tar -xzf $TAR_MONGO_PERL_DRIVER_PACKAGE

    # PERFORM THE PACKAGE BUILD
    #
    # Note: RE: Warnings unknown substitution variable ${shlibs:Depends}
    # See: http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=566837
    # (Fixed in dpkg version 1.15.6)
    #
    cd $MONGO_PERL_DRIVER_PACKAGE-$VERSION
    debuild --no-lintian -uc -us
    cd "$OUR_DIR"

fi

if [ -f "/etc/redhat-release" ]; then
    # Create RPM packaging.
    echo "# Building RPM package"

    # Remove the pod file.
    cd "$OUR_DIR";
    rm $DEPLOY_DIR/$MONGO_PERL_DRIVER_PACKAGE/usr/lib64/perl5/perllocal.pod

    VERSION=$VERSION \
    RELEASE=$RELEASE \
    PACKAGE=$MONGO_PERL_DRIVER_PACKAGE \
        rpmbuild -v \
        --define "_builddir $OUR_DIR/$DEPLOY_DIR/$MONGO_PERL_DRIVER_PACKAGE" \
        --define "_rpmdir %(pwd)/rpms" \
        --define "_srcrpmdir %(pwd)/rpms" \
        --define "_sourcedir %(pwd)/../" \
        -ba n2-mongo-perl-driver.spec
fi
