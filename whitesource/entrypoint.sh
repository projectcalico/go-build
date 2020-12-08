#! /bin/bash
set -e

if [ -z "${WHITE_SOURCE_APIKEY}" ]; then
      echo "WHITE_SOURCE_APIKEY must be specified"
      exit 1
fi

if [ -z "${WHITE_SOURCE_PRODUCT}" ]; then
      echo "WHITE_SOURCE_PRODUCT must be specified"
      exit 1
fi

if [ -z "${WHITE_SOURCE_PRODUCT_VERSION}" ]; then
      echo "WHITE_SOURCE_PRODUCT_VERSION must be specified"
      exit 1
fi

if [ -z "${WHITE_SOURCE_PROJECT}" ]; then
      echo "WHITE_SOURCE_PRODUCT_VERSION must be specified"
      exit 1
fi

if [ -z "${SCAN_IMAGES}" ]; then
      echo "SCAN_IMAGES must be specified"
      exit 1
fi

DOCKER_INCLUDES=""
for SCAN_IMAGE in ${SCAN_IMAGES}
do
  REPO=$(cut -d':' -f1 <<<"$SCAN_IMAGE")
  TAG=$(cut -d':' -f2 <<<"$SCAN_IMAGE")
  if [ -z ${TAG} ]; then
    TAG=latest
  fi

  if [ -n "${PULL_IMAGES}" ]; then
    docker pull "${REPO}":"${TAG}"
  fi

  IMAGE_ID=$(docker images --format="{{.Repository}}:{{.Tag}} {{.ID}}" | grep "${REPO}":"${TAG}" | cut -d' ' -f2)
  if [ -z "${IMAGE_ID}" ]; then
    echo "Could find image id for image '${REPO}":"${TAG}'"
    exit 1
  fi
  DOCKER_INCLUDES+=" ${IMAGE_ID}"
done

DOCKER_INCLUDES=$(echo "${DOCKER_INCLUDES}" | xargs)

DOCKER_INCLUDES=${DOCKER_INCLUDES} bash wss-unified-docker.config.template

java -jar wss-unified-agent-20.7.1.jar -c wss-unified-docker.config -apiKey "${WHITE_SOURCE_APIKEY}" -product "${WHITE_SOURCE_PRODUCT}" \
  -productVersion "${WHITE_SOURCE_PRODUCT_VERSION}" -project "${WHITE_SOURCE_PROJECT}"