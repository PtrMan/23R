### What is this?

This is a repo for a reasoner and a vision system. Currently only the vision system is published.

### How to run?

**a)** download NN weights <br />

* run `./dlModelVision.sh` to download current weights

**b)** build <br />

* modify path to Nim lib in ./build.sh
* run `./build.sh`

#### How to run in network mode?

**a)** start proxy on a computer <br />

code from https://gist.github.com/PtrMan/b05e71718626deaa141d8ad0a1598c20

**b)**  connect vision sytem to proxy <br />

`./a net 127.0.0.1`

**c)**  connect camera feed script to proxy <br />



