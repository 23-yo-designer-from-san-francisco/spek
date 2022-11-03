# Building the OS X bundle

Using [Homebrew](http://brew.sh) install build dependencies:

    brew install autoconf automake coreutils git libtool pkg-config ffmpeg gettext wxmac
    brew link --force gettext

Bundle Spek:

    ./dist/osx/bundle.sh
