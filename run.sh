#!/bin/bash
# Usage:
#   ./run.sh                                    # provision all machines
#   ./run.sh --limit pepinaco                # only linux dev machine
#   ./run.sh --limit macbook                    # only macOS laptop
#   ./run.sh --limit osx-agent                  # only macOS agent
#   ./run.sh --tags docker --limit pepinaco  # single role on single machine

ansible-playbook site.yml --ask-become-pass "$@"
