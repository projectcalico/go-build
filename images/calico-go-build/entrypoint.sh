#!/bin/bash

# Add local user
# Either use the LOCAL_USER_ID if passed in at runtime or fallback

USER_ID=${LOCAL_USER_ID:-9001}

# Make sure the cache directories exist.  We use /tmp-like permissions to
# allow all users to create files in there.
mkdir -p /caches/go-build-cache
mkdir -p /caches/go-mod-cache
chmod 1777 /caches/go-build-cache
chmod 1777 /caches/go-mod-cache

if [ "${RUN_AS_ROOT}" = "true" ]; then
  export GOCACHE=/caches/go-build-cache/root
  export GOMODCACHE=/caches/go-mod-cache/root
  exec "$@"
else  
  export GOCACHE=/caches/go-build-cache/$USER_ID
  export GOMODCACHE=/caches/go-mod-cache/$USER_ID
fi

echo "Starting with UID: $USER_ID" 1>&2
# Don't pass "-m" to useradd if the home directory already exists,
# (which can occur if it was volume mounted in) otherwise it will fail.
if [[ ! -d "/home/user" ]]; then
  useradd -m -U -s /bin/bash -u "$USER_ID" user
else
  useradd -U -s /bin/bash -u "$USER_ID" user
fi

export HOME=/home/user

if [ -n "$EXTRA_GROUP_ID" ]; then
  echo "Adding user to additional GID: $EXTRA_GROUP_ID" 1>&2
  # Adding the group can fail if it already exists.
  if groupadd --gid "$EXTRA_GROUP_ID" group; then
    usermod -a -G group user
  else
    echo "Adding user to existing group instead" 1>&2
    usermod -a -G "$(getent group "$EXTRA_GROUP_ID" | cut -d: -f1)" user
  fi
fi

exec /usr/bin/su-exec user "$@"
