#!/usr/bin/env bash

export VEIL_TARGET_HOST
export VEIL_REMOTE_USER
export VEIL_DATA


data() {
  machine=${1:?need machine name as first argument}
  VEIL_DATA=$(nix eval --option warn-dirty false "./#nixosConfigurations.$machine.config.veil" --json)
  VEIL_TARGET_HOST=$(jq --raw-output .deployTarget <<< "$VEIL_DATA")
  VEIL_REMOTE_USER=$(jq --raw-output .deployUser 2>/dev/null <<< "$VEIL_DATA")
  if [ "$VEIL_REMOTE_USER" = "null" ]; then
    VEIL_REMOTE_USER="$USER"
  fi
}


veil:data() {
  jq . <<< "$VEIL_DATA"
  echo "VEIL_TARGET_HOST: $VEIL_TARGET_HOST;"
  echo "VEIL_REMOTE_USER: $VEIL_REMOTE_USER;"
}


veil:machines() {
  nix eval --option warn-dirty false "./#nixosConfigurations" --apply 'builtins.attrNames' --json |
    jq --raw-output --exit-status '.[]'
}


veil:push() {
  to_clean=()
  trap 'rm --force --verbose "${to_clean[@]}"' ERR EXIT
  while IFS= read -r -d $'\0' d <&3; do
    # Get secret & host data from veil
    eval "$(jq --raw-output --exit-status 'to_entries | .[] | .key + "=" + (.value | @sh) + ";"' <<< "$d")"
    remote="$VEIL_REMOTE_USER@$VEIL_TARGET_HOST"

    # Write script executable & setup its cleanup
    path=$(mktemp -t veil_XXXXXXX)
    to_clean+=("$path")
    echo "$script" > "$path"
    chmod +x "$path"

    # Run script and save its value
    value=$("$path" | cat -)

    # Sanity check
    echo "$name: ${value:0:1}...${value: -1} (${#value} characters) --> ${remote%@null}:$target" 1>&2
    [ ${#value} -gt 4 ] || {
      echo "script: '$script'" 1>&2
      echo "Error: something went wrong with '$name'!" 1>&2
      exit 1
    }

    # Copy secret to final destination
    if [ "$VEIL_TARGET_HOST" = "null" ]; then
      sudo mkdir -p "${target%/*}"
      echo "$value" | sudo tee "$target" >/dev/null
      sudo chown "$user:$group" "$target"
      sudo chmod o= "$target"
    else
      ssh $NIX_SSHOPTS -t "$remote" "sudo mkdir -p '${target%/*}' && echo '$value' | sudo tee '$target' >/dev/null; sudo chown '$user:$group' '$target'; sudo chmod o= '$target'"
    fi
  done 3< <(jq --compact-output --raw-output0 '.secrets | map(.)[]' <<< "$VEIL_DATA")
}


veil:deploy() {
  local deploy_opts=()
  if [ "$VEIL_REMOTE_USER" != "root" ]; then
    deploy_opts+=(--ask-sudo-password --use-remote-sudo)
  fi
  nixos-rebuild \
    --option 'extra-experimental-features' 'nix-command flakes' \
    --target-host "$VEIL_REMOTE_USER@$VEIL_TARGET_HOST" \
    "${deploy_opts[@]}" \
    "$@" \
    --flake "./#$machine"
}


veil:dev-vm() {
  local vmpath=result/bin/run-$machine-vm
  [ -x "$vmpath" ] || err "No '$vmpath'. You need to build the VM first!"
  if command -v kitty &>/dev/null; then
    kitty ${DEBUG:+--hold} sh -c "env 'SECRETDATA=$PWD/secrets' '$vmpath' ${@@Q} || read" &
  else
    ${TERMINAL:-xterm} env "SECRETDATA=$PWD/secrets" "$vmpath" "$@" &
  fi
}

veil:sshvm() {
  ssh "$VEIL_REMOTE_USER@127.0.0.1" -p 9922 \
    -o IdentitiesOnly=yes \
    -o PreferredAuthentications=publickey \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    -o LogLevel=ERROR
}

# Helpers & Argument Handling

log() { printf -v tmstmp '%(%F %T %Z)T'; echo -e "\e[0;33m[$tmstmp]\e[0m $*" 1>&2; }
err() { log "\e[1;91mERROR:\e[0m $*"; exit 1; }

if [ "$0" = "${BASH_SOURCE[0]}" ]; then
  cmd=${1:?Need an action to perform as first argument (push, unlock)}
  shift
  if [ "$cmd" = "machines" ]; then
    veil:"$cmd" "$@"
    exit
  fi
  machine=${1:?Need a target machine as second argument. Possibilities:$'\n\n'$(veil:machines)}
  shift
  set -o errexit -o errtrace -o pipefail -o nounset ${DEBUG:+-o xtrace}
  data "$machine"
  veil:"$cmd" "$@"
fi

