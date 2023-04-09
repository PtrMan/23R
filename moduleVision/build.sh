rm ./a

# compile Nim to C++ target
nim cpp --noMain --noLinking --header:visionSys0.h visionSys0.nim    && \
g++  -o a `pkg-config --cflags --libs opencv`      -I/home/r0b3/root/installedPrograms/nim-1.6.10/lib  -I$HOME/.cache/nim/visionSys0_d $HOME/.cache/nim/visionSys0_d/*.cpp a.cpp
