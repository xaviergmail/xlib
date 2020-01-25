#!/bin/sh

tmux kill-session -t mobdebug
tmux new-session "tmux source-file ./mobdebug.tmux"
