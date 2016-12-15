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
  addgroup -g $EXTRA_GROUP_ID group
  addgroup user group
fi  

exec /sbin/su-exec user "$@"
