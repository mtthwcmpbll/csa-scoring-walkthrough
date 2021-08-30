#!/usr/bin/env bash
cloud-suitability-analyzer/python/ruler.py -d custom-rules/weighted -m verify
cloud-suitability-analyzer/python/ruler.py -d custom-rules/weighted -m replace
cloud-suitability-analyzer/python/ruler.py -d custom-rules/weighted -m add