## vi99 Editor for TI-99

This is a work in progress attempt to make a vi "like" editor for TI-99. The editor was compiled with Camel99 Forth ITC. Since TI99 does not have a conventional shell, the Forth interpreter is used a shell providing ls, ls-l commands and a way to start the editor.

The editor is not a complete version of vi but provides some basic
functionality. See the vimanpage for the feature set and commands. 

### Quick Start
To use the editor with Classic99, unzip the zip file into a folder on your PC.
- Under the "Disk" menu, select that folder as DSK1. of type "FIAD".
- Under the "Cartridge" menu select "Editor/Assembler"
- Press a key to see the TI-99 menu screen
- Press 2 for EDITOR/ASSEMBLER
- Press 5   RUN PROGRAM FILE 
- At the prompt type DSK1.VI9980
- The vi99 command shell screen should appear.
- Type vi to start the editor

### Hardward Requirements
vi99 is an 80 column editor and therefore requires the F18 video card or equivalent functionality on an emulator like Classic99. 

#### Command Shell
![Alt text](https://github.com/bfox9900/vi99/blob/main/images/vi99-command-shell.png "vi99 Command Shell")

#### ls Command 
![Alt text](https://github.com/bfox9900/vi99/blob/main/images/lscommand.png "vi99 Command Shell")


