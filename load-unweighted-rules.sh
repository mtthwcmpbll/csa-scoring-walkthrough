#!/usr/bin/env bash
cloud-suitability-analyzer/python/ruler.py -d custom-rules/unweighted -m verify
cloud-suitability-analyzer/python/ruler.py -d custom-rules/unweighted -m replace
cloud-suitability-analyzer/python/ruler.py -d custom-rules/unweighted -m add