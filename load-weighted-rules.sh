#!/usr/bin/env bash
../ruler.py -d custom-rules/weighted -m verify
../ruler.py -d custom-rules/weighted -m replace
../ruler.py -d custom-rules/weighted -m add