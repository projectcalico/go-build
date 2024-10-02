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
  -org-url string
        Semaphore organization URL
  -skip-dirs string
        comma separated list of directories to skip when searching for Semaphore pipeline files
  -token string
        Semaphore API token
```

You can specify dirs that contain semaphore pipeline files (using `-dirs`)
and/or files that are semphore pipeline files (using `-files`).
If using `-dirs`, this tool assumes all YAML files in the folder recursively are Semaphore pipeline files.
To skip specific folders in the directories specified, use `-skip-dirs`

Set the organization using either `-org` or `-org-url` as it is needed to determine
where to send the validation requests.

The token needs to be a valid [Semaphore API token](https://docs.semaphoreci.com/reference/api-v1alpha/#authentication).
It will try to use the `SEMAPHORE_API_TOKEN` environment variable if flag is empty.

### Examples

Using `latest` as `${GOBUILD_VERSION}`

1. Give a project `<path-to-dir>` with semaphore files in `<path-to-dir>/.semaphore` directory,
   below is how to validate the files in that directory.

  ```sh
  docker run --rm -v <path-to-dir>:<location-in-container>:ro calico/go-build:latest semvalidator -dirs <location-in-container>/.semaphore -org <semaphore-organization> -token <semaphore-token>
  ```

1. Give a project `<path-to-dir>` with semaphore files in `<path-to-dir>/.semaphore` directory,
   below is how to validate the files in that directory using `-org-url` flag with `$SEMAPHORE_ORGANIZATION_URL` environment variable.

  ```sh
  docker run --rm -v <path-to-dir>:<location-in-container>:ro calico/go-build:latest semvalidator -dirs <location-in-container>/.semaphore -org-url ${SEMAPHORE_ORGANIZATION_URL} -token <semaphore-token>
  ```

1. Give a project `<path-to-dir>` with semaphore file in `<path-to-dir>/.semaphore/semaphore.yml` directory,
   below is how to validate the files in that directory.

  ```sh
  docker run --rm -v <path-to-dir>:<location-in-container>:ro calico/go-build:latest semvalidator -files <path-to-dir>/.semaphore/semaphore.yml -org <semaphore-organization> -token <semaphore-token>
  ```
