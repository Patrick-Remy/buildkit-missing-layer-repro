#/bin/sh

set -e

buildkit_image=${BUILDKIT_IMAGE:-moby/buildkit:v0.8.1-rootless}
dockerfile=${BUILD_DOCKERFILE:-Dockerfile}
entrypoint=${ENTRYPOINT:-entrypoint.sh}

# Build image
build() {
  docker run \
      -it \
      --rm \
      --privileged \
      -v $PWD:/tmp/work \
      --entrypoint='/bin/sh'  \
      $buildkit_image \
        -c "
          /usr/bin/buildctl-daemonless.sh build \
            --frontend dockerfile.v0 \
            --local context=/tmp/work \
            --local dockerfile=/tmp/work \
            --opt filename=${dockerfile} \
            --import-cache type=local,mode=max,src=/tmp/work/buildkit-import.cache/1 \
            --export-cache type=local,mode=max,dest=/tmp/work/buildkit.cache/1 \
        && \
          /usr/bin/buildctl-daemonless.sh build \
            --frontend dockerfile.v0 \
            --local context=/tmp/work \
            --local dockerfile=/tmp/work \
            --opt filename=${dockerfile} \
            --import-cache type=local,mode=max,src=/tmp/work/buildkit-import.cache/2 \
            --export-cache type=local,mode=max,dest=/tmp/work/buildkit.cache/2 \
        && \
          /usr/bin/buildctl-daemonless.sh build \
          --frontend dockerfile.v0 \
          --local context=/tmp/work \
          --local dockerfile=/tmp/work \
          --opt filename=${dockerfile} \
          --import-cache type=local,mode=max,src=/tmp/work/buildkit.cache/1 \
          --import-cache type=local,mode=max,src=/tmp/work/buildkit.cache/2 \
          --output type=tar,dest=/tmp/work/image.tar
        "
}

echo "Prepare current folder permissions for unprivileged container"
chmod 777 .


if [ "$1" != "skip-create-cache" ]; then
  echo "Cleanup caches and image"
  [ ! -f image.tar ] || rm image.tar
  [ ! -d image ] || rm -rf image
  [ ! -d buildkit-import.cache ] || rm -rf buildkit-import.cache
  [ ! -d buildkit.cache ] || rm -rf buildkit.cache buildkit-import.cache

  echo "Create cache (and image) from scratch"
  build

  echo "Extracting image.tar"
  [ -d image ] || mkdir image
  tar -xf image.tar -C image

  [ -f image/${entrypoint} ] || { echo "image/${entrypoint} is missing!"; exit 1; }
  echo "image/${entrypoint} exists – expected, cleanup"
else
  echo "Skipping creating caches from scratch"
fi


# Retry, as sometimes only the second try creates the broken image
for retry in 1 2; do
  echo "Cleanup image and rename cache for import"
  [ ! -f image.tar ] || rm image.tar
  [ ! -d image ] || rm -rf image
  [ ! -d buildkit-import.cache ] || rm -rf buildkit-import.cache
  [ ! -d buildkit.cache ] || mv buildkit.cache buildkit-import.cache

  echo "Build it again, and import caches"
  build

  echo "Extracting image.tar"
  [ -d image ] || mkdir image
  tar -xf image.tar -C image;

  [ -f image/${entrypoint} ] || { echo "image/${entrypoint} is missing!"; exit 1; }
  echo "image/${entrypoint} exists – not expected, retry"
done

echo "Reached max number of retries to reproduce issue, setup seems not to be affected"
