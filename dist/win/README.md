## Building the Windows installer

This is be done in two steps:

 * Cross-compiling spek.exe using [MXE](http://mxe.cc/).
 * Building the MSI package under Windows.

For the first step you can use any Unix-y environment. Set up
[MXE](http://mxe.cc/#tutorial), you can use the code from
[this repository](https://github.com/alexkay/mxe/tree/spek) or the official one.

Build Spek dependencies:

    make pthreads ffmpeg wxwidgets

Build Spek, adjusting `bundle.sh` variables as necessary:

    ./dist/win/bundle.sh

For the second step, you will need a Windows box with
[WiX](http://wix.sourceforge.net/) installed. Copy over the entire `dist/win`
directory and run `bundle.bat`.
