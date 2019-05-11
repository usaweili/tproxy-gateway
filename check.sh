#!/bin/bash

killall curl && curl -fs google.com && exit 0 || exit 1