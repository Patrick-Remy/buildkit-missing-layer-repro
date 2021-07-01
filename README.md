# BuildKit missing layer bug example

This repository aims to easily reproduce a current BuildKit bug (at least
reproducible since [`dda009a`](https://github.com/moby/buildkit/commit/dda009a58c76e3e54b4539dce23623eefcc4428c)).

## 🐛 Bug description
When using raw buildctl commands to build this Dockerfile and export caches,
then import them, there is a big chance that the resulting image misses the
`/docker-entrypoint.sh`.

## Reproduce it!
> HINT: Ensure to be an enough priviliged user, to delete files and folders
> created by the buildkit container.

Clone this repository and run `./build-script.sh`. It will take some time, to
execute the required steps. On finish it will either:
- Exit 1 `image/docker-entrypoint.sh is missing!`, the resulting image will be
  in the `image` directory.
- Exit 0 `Reached max number of retries to reproduce issue, setup seems not to be affected`,
  either the used buildkit version or some modifications on Dockerfile or files
  in the build context lead to a successful build.

You can adjust the used buildkit image by setting the environment variable
`BUILDKIT_IMAGE=your/buildkit:12345-rootless`.

## ⚠️ Caution when modifying the Dockerfile
In my personal experience of reproducing, when trying to remove any of the 
statements in the Dockerfile, the script no more fails.

