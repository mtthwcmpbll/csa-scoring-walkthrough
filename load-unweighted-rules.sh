#!/usr/bin/env bash
../ruler.py -d custom-rules/unweighted -m verify
../ruler.py -d custom-rules/unweighted -m replace
../ruler.py -d custom-rules/unweighted -m add