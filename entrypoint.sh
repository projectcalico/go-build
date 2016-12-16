#!/bin/bash

# Add local user
# Either use the LOCAL_USER_ID if passed in at runtime or
# fallback

USER_ID=${LOCAL_USER_ID:-9001}

echo "Starting with UID : $USER_ID"
adduser -D -s /bin/bash -u $USER_ID -g "" user
export HOME=/home/user

if [ -n "$EXTRA_GROUP_ID"  ]; then
  echo "Adding user to additional GID : $EXTRA_GROUP_ID"
  # Adding the group can fail if it already exists.
  if addgroup -g $EXTRA_GROUP_ID group; then
    addgroup user group
  else
    echo "Adding user to existing group instead"
    addgroup user `getent group $EXTRA_GROUP_ID | cut -d: -f1`
  fi
fi  

exec /sbin/su-exec user "$@"
