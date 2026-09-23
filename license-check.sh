#!/usr/bin/env bash
set -Eeuo pipefail
set -a
. /etc/ssh-store-agent/agent.env
set +a
node /opt/ssh-store-agent/license-agent-check.js
