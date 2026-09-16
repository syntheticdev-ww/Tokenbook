#!/bin/zsh
cd -- "${0:A:h}"
exec node scripts/game.mjs run
