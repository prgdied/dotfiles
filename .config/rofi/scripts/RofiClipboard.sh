#!/bin/bash

if [ -z "$@" ]; then
    cliphist list
else
    cliphist decode <<< "$@" | wl-copy
fi
