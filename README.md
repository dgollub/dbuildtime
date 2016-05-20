# DBuildTime

Easily get timing information on your project's build times.

Based on Casey Muratori's (CTime Utility)[https://gist.github.com/cmuratori/8c909975de4bb071056b4ec1651077e8] (the source code can be found in the (orgsrc)[orgsrc] folder).

Casey showcases his tool on his Youtube channel here: [Overview of the CTime Utility](https://www.youtube.com/watch?v=LdMHyGxfg6U)


# Difference to CTime

dbuildtime is cross-platform (can be build on Mac OSX, Windows and Linux) out of the box thanks to the (D programming language)[dlang.org].

**Important**
dbuildtime is not designed or written to be binary compatible with ctime output files. It may work, it may not work.


# How To Build

Make sure you have the latest (D compiler)[http://dlang.org/] installed. I use (DMD Compiler v2.071.0)[http://dlang.org/download.html].

Use (dub)[https://code.dlang.org/getting_started] to build dbuildtime.

Alternativly you can use the `build.sh` script to build dbuildtime.


# Usage

dbuildtime is a simple utility that helps you keep track of how much time you spend building your projects.
You use it the same way you would use a begin/end block profiler in your normal code, only instead of profiling your code, you profile your build.

## BASIC INSTRUCTIONS

On the very first line of your build script, you do something like this:

```bash
   dbuildtime -begin timings_file_for_this_build.ctm
```

and then on the very last line of your build script, you do

```bash
   dbuildtime -end timings_file_for_this_build.ctm
```

That's all there is to it! dbuildtime will keep track of every build you do, when you did it, and how long it took.
Later, when you'd like to get a feel for how your build times have evolved, you can type

```bash
   dbuildtime -stats timings_file_for_this_build.ctm
```

and it will tell you a number of useful statistics!


## ADVANCED INSTRUCTIONS

dbuildtime has the ability to track the difference between _failed_ builds and _successful_ builds.
If you would like it to do so, you can capture the error status in your build script at whatever point you want, for example:
```bash
   REM Windows BATCH file
   set LastError=%ERRORLEVEL%
```

and then when you eventually call dbuildtime to end the profiling, you simply pass that error code to it:

```bash
   REM Windows BATCH file
   dbuildtime -end timings_file_for_this_build.ctm %LastError%
```

dbuildtime can also dump all timings from a timing file into a textual format for use in other types of tools.
To get a CSV you can import into a graphing program or database, use:

```bash
   dbuildtime -csv timings_file_for_this_build.ctm
```

Also, you may want to do things like timing multiple builds separately, or timing builds based on what compiler flags are active.
To do this, you can use separate timing files for each configuration by using the shell variables for the build at the filename, eg.:

```bash
   dbuildtime -begin timings_for_%BUILD_NAME%.ctm
   ...
   dbuildtime -end timings_for_%BUILD_NAME%.ctm
```


# License and Copyright

License: Public Domain


Copyright (c) 2016 by Daniel Kurashige-Gollub <daniel@kurashige-gollub.de>
