# UDOO Arduino CLI

It's for anybody who is looking for a headless command line compiler and flasher for your UDOO board to build and upload your Arduino sketches directly and internally from inside a UDOO Linux shell.

![udoo-arduino-cli-overview-screenshot](https://cloud.githubusercontent.com/assets/410087/6635931/662aaf2c-c96b-11e4-849d-a7577223e331.png)

<br>

### Motivation

We are using great [UDOO boards](http://www.udoo.org) to build our products. But when we had to update and flash our sketches to the Arduino Due it was a boring task to start Arduino IDE on second computer, connect via USB, remove Jumper JN18, compile and flash etc. This was even time-consuming when trying to roll-out to a number of devices.

In case of a less resource consuming OS we are running the Linux OS on UDOO board without Xserver. So normal Arduino IDE on board was no option.

<br>

### Usage

Let's assume that you want to run one of the famous blink examples on your Arduino Due.  
Now you can compile and flash with this easy command:

````
udoo-arduino-build --flash Blink.ino
````

All is done local on your UDOO, you do not need X or Java or ... :-)

<br>

### Installation

If you want to do it like above, just install the latest deb packages to your UDOO.  
[check and download latest releases](https://github.com/TomFreudenberg/udoo-arduino-cli/releases), e.g.:

````
cd /tmp
wget https://github.com/TomFreudenberg/udoo-arduino-cli/releases/download/v1.6.1-pre1/udoo-arduino-cli-1.6.1-pre1_all.deb
sudo dpkg -i udoo-arduino-cli-1.6.1-pre1_all.deb
````

All done!

<br>

### Getting started (the quick way)

Complete magic is handled by the script `udoo-arduino-build` which is also linked to `/usr/local/bin` so that you can enter this command system-wide.

**Build usage:**

e.g. compile and flash `MySketch.ino` and add the standard `Servo` library to your build process:

````
udoo-arduino-build --flash -L Servo.cpp MySketch.ino
````

**Flash usage:**

e.g. flash previously created `MySketch.bin`:

````
udoo-arduino-build --flash MySketch.bin
````

> The flash procedure is handled by included `bossac` utility and via the internal processors serial communication device (normally `/dev/ttymxc3`).

<br>

### Make your sketch (extended usage)

There are some really useful cmdline options available for `udoo-arduino-build` script.

````
udoo-arduino-build [-I <path>] [-L <library.cpp>] [-o <path> [--fast]] [--copy] [--flash] sketch.ino [<sources.cpp>]"
````

##### --help

Show help and command usage info.

##### --flash

Run the flashing process after build or as action

##### -I \<include-path\>

Append additional folders to INCLUDES path for compiling your sketch.ino. Path may be relative or absolute. If you divided your source into several pieces, you may include custom library folders like ` -I ./my_libs `

##### -L \<library.cpp\>

Add necessary standard libraries to your project. Correct library path is automatically located by searching the libraries main .cpp-file. If you need the Servo library, you can add it just by `-L Servo.cpp`. You can add this option as often as needed like ` -L Servo.cpp -L Wire.cpp `

##### -o \<build-path\>

Normally the script will create a temporary folder like `/tmp/udoo-arduino-build-12345` and remove this folder after build process – even when build was successful or not. If you like to use a defined folder it is possible to set your own `build-path` by this option.

##### --fast

Fast is an addtional option to build process. Instead of rebuilding all sources (your and standard Arduino) the `--fast` option will try to re-use already built objects from standard sources. To use this option, you have to specify your own `-o build-path` because the temporary folders will be dropped each time.

##### --copy

After a successful build of your sketch.ino the generated sketch.bin will be copied and backuped from your `build-path`to your sketch `project-path`. You can flash this binary on multiple boards or publish it to others.

##### -D \<internal UART device for interprocessor communication\>

If on any reason necessary you can change the default device `ttymcx3` when flashing your sketch.

##### -A \<arduino (ide) installation path\>

If you do not use default installation of `udoo-arduino-cli` or want to try another build environment, you may change the base installation path.

##### --no-arduino-headers

To allow maximum control of the build process you can disable some magic like the appendixes for automatically compatibility. This option will prevent `include "Arduino.h"` headers.

<br>

### Compatibility

This is 100% Arduino IDE, so it is 100% compatible to your existing sources. The Arduino IDE does some magic before running the compile process and so we do it too - that is: Adding references like `#include <Arduino.h>` of standard Arduino headers so that you may use code like `digitalWrite(13, HIGH);` without changing your codes. All should be getting compiled as in Arduino IDE.

<br>

---

<br>

### Some background information

##### Looking for a suitable solution

I read a lot of information on the internet but did not find anywhere a suitable solution. The cool [arduino-mk project](https://github.com/sudar/Arduino-Makefile) did not handle the Arduino Due micro-processor. At least I tried to re-engineer the command sequences from Arduino IDE and got some really useful hint from [user fletchers](http://www.udoo.org/forum/member35529.html) post on [UDDO forum](http://www.udoo.org/forum/here-script-compile-upload-arduino-sketches-via-cli-t1822.html).

Ongoing with the idea behind his script I decided to build a complete CLI which should be easy to install on UDOO boards. This ends-up in this new repository and package. You can download an installable debian package directly from release section: [show releases and downloads](https://github.com/TomFreudenberg/udoo-arduino-cli/releases)

<br>

##### How was this environment created?

I built up the first release based on original Arduino IDE (stable release 1.6.1) taken from http://arduino.cc/en/Main/Software. In case that I do not wanted any IDE part, I dropped any file and folder referencing this. The standard Arduino IDE is not built for ARM device so I tried to run the build process on my UDOO. This did not worked in a number of issues I would not have to solve. So I extract the Arduino IDE 1.5.8 from [UDOO 1.1 image](http://download.udoo.org/files/UDOO_Unico/Quad_img/UDOObuntu_img/UDOObuntu_quad_v1.1.zip) (see: /opt/arduino-1.5.8) and replaced the folder `hardware/tools` with the folder from UDOO image. Last I checked all libraries and ran some tests to find out, that Arduino 1.6.1 changed something in `UARTClass` and `USARTClass`. Those contained only minor changes and I replaced this 5 source files also with the correspondings from UDOO image.

That's it! Now you have an environment with Arduino 1.6.1 sources and libraries and an UDOO compatible Arduino Due (SAM3X) gcc-4.8.3 (20131129) toolset. Last but not least also the `bossac` flashing tool works well.

<br>

### References

Here are some of the ressources which I consumed during this work.

##### UDOO pages
1. http://www.udoo.org/downloads/  
1. https://github.com/UDOOboard/Arduino  
1. http://www.udoo.org/forum/here-script-compile-upload-arduino-sketches-via-cli-t1822.html  
1. http://www.udoo.org/forum/program-arduino-without-using-arduino-ide-t1642.html  
1. http://www.udoo.org/forum/debian-jessie-rootfs-with-gpu-vpu-t693.html  
1. http://www.udoo.org/forum/eclipse-ide-atmel-asf-alternative-arduino-ide-t1260.html  

##### ARDUINO pages
1. http://arduino.cc/en/Main/Software  
1. https://github.com/arduino/Arduino/tree/1.6.1  

##### MIXED internet pages
1. https://github.com/amperka/ino  
1. http://www.shumatech.com/web/products/bossa  
1. http://www.atwillys.de/content/cc/using-custom-ide-and-system-library-on-arduino-due-sam3x8e/?lang=en  
1. http://arduino.stackexchange.com/questions/1312/not-using-the-ide-and-understanding-the-compilation-linking-upload-process  
1. http://www.linuxcircle.com/2013/05/15/programming-and-uploading-arduino-sketch-without-ide/  
1. http://hardwarefun.com/tutorials/compiling-arduino-sketches-using-makefile  
1. http://stackoverflow.com/questions/15184932/how-to-upload-source-code-to-arduino-from-bash  
1. http://www.cloud-rocket.com/2014/05/programming-arduino-due-atmel-studio-asf/  

<br>

