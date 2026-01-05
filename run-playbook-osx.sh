#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <playbook-name>"
    echo ""
    echo "Available playbooks:"
    ls -1 playbooks/osx/*.yml 2>/dev/null | sed 's|playbooks/osx/||' | sed 's|\.yml$||' | sort
    exit 1
fi

PLAYBOOK="playbooks/osx/$1.yml"

if [ ! -f "$PLAYBOOK" ]; then
    echo "Error: Playbook '$PLAYBOOK' not found"
    echo ""
    echo "Available playbooks:"
    ls -1 playbooks/osx/*.yml 2>/dev/null | sed 's|playbooks/osx/||' | sed 's|\.yml$||' | sort
    exit 1
fi

ansible-playbook "$PLAYBOOK" --ask-become-pass
