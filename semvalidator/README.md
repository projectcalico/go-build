# semvalidator

This allows running validations on semaphore pipeline files.

## Usage

The help give all the required options.

```sh
$ docker run --rm calico/go-build:${GOBUILD_VERSION} semvalidator --help
Usage of semvalidator:
  -debug
        enable debug logging
  -dirs string
        comma separated list of directories to search for Semaphore pipeline files
  -files string
        comma separated list of Semaphore pipeline files
  -org string
        Semaphore organization
  -skip-dirs string
        comma separated list of directories to skip when searching for Semaphore pipeline files
  -token string
        Semaphore API token
```

You can specify dirs that contain semaphore pipeline files (using `-dirs`)
and/or files that are semphore pipeline files (using `-files`).

The organization is need to determine the Semaphore instance.
It will also use the value of `SEMAPHORE_ORGANIZATION` environment variable if flag is empty.

The token needs to be a valid [Semaphore API token](https://docs.semaphoreci.com/reference/api-v1alpha/#authentication).
It will try to use the `SEMAPHORE_API_TOKEN` environment variable if flag is empty.

### Examples

Using `latest` as `${GOBUILD_VERSION}`

1. Give a project `<path-to-dir>` with semaphore files in `<path-to-dir>/.semaphore` directory,
   below is how to validate the files in that directory.

  ```sh
  docker run --rm -v <path-to-dir>:<location-in-container>:r calico/go-build:latest semvalidator -dirs <location-in-container>/.semaphore -org <semaphore-organization> -token <semaphore-token>
  ```

1. Give a project `<path-to-dir>` with semaphore file in `<path-to-dir>/.semaphore/semaphore.yml` directory,
   below is how to validate the files in that directory.

  ```sh
  docker run --rm -v <path-to-dir>:<location-in-container>:r calico/go-build:latest semvalidator -files <path-to-dir>/.semaphore/semaphore.yml -org <semaphore-organization> -token <semaphore-token>
  ```
