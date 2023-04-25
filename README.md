### What is this?

This project is a :alien:system, it doesn't work like your usual machine learning (ML) systems. <br />
It is a agent with true autonomy :robot:🧠, it deals with situations in realtime (<200ms reaction time), it can run all day, it learns lifelong and incrementally.

This project consists out of the intelligent "core" and comes with a vision subsystem. A subsystem to communicate with the system in natural language is also included. This repository doesn't come pre-packaged with other tooling/subsystems.

The vision subsystem (which isn't integrated/used yet) also works in realtime, it also learns lifelong and incrementally. See in https://github.com/PtrMan/23R/tree/main/moduleVision for the vision system.

### How to install required dependencies?

```curl https://nim-lang.org/choosenim/init.sh -sSf | sh```

### How to run?

There are two ways to run, the shell is preferable to do experiments with the reasoner, while the web interface is much more user friendly, but the reasoner there runs in real-time and always processes requests as soon as they arive.

*shell* <br />
```nim compile --run entryShell.nim``` <br />

Note that the shell waits for user input and doesn't run in real-time because it waits for input!

*web mediator+net-NAR+webserver* <br />

start mediator

    python ./partMediator/mediator.py &

run webserver

    node ./partUiServer/a.js &

run net-NAR

    nim compile --threads:on --run entryNetUdpClient.nim

### How to input natural language?

write > as a prefix in the shell. This is currenlty not implemented in the web interface! <br />
example:

    >Tom is a furry cat

### How to input in formal language?

The formal language to communicate with the system with non-natural language is done in [narsese](https://github.com/PtrMan/23R/tree/main/docs/narsese.md).

### Wait! I care about theory!

This system is a implementation of a non-axiomatic reasoning system. It comes with some additions on top of the NARS-theory which are inspired by relational-frame theory.

### Wait! Why doesn't this come pre-packaged with 'batteries included' like Python or a webbrowser etc.?

To keep this project/repository simple as in keep-it-small-stupid (KISS).
