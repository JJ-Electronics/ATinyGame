#!/bin/bash
which avra || sudo apt install avra
avra ATinyGame.asm -l ATinyGame.lst
cat ATinyGame.hex | wl-copy
