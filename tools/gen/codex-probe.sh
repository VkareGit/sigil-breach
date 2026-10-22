#!/usr/bin/env bash
export PATH=$HOME/.nvm/versions/node/v24.21.0/bin:$PATH
codex features list 2>&1 | grep -iE 'image|gen'
echo ---config
grep -n -iE 'image|features|model' ~/.codex/config.toml
echo ---generated
ls ~/.codex/generated_images 2>/dev/null | head -3
