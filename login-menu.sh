#!/usr/bin/env bash
if [[ $- == *i* && -t 1 && -n "${SSH_CONNECTION:-}" && "${EUID}" -eq 0 && -x /usr/local/sbin/ssh-store-admin-menu && -z "${SSH_STORE_MENU_ACTIVE:-}" ]]; then
  export SSH_STORE_MENU_ACTIVE=1
  /usr/local/sbin/ssh-store-admin-menu
fi
