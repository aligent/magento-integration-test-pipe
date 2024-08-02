# Aligent Magento Integration and API Functional Testing Pipe

A bitbucket pipe for running Magento integration and api functional tests 

It is designed to be run parallelly so you can leverage bitbucket parallel steps. [Example pipeline](#example-pipeline)

The pipe detects a `composer.lock` file and installs packages. If no `composer.lock` file is found, the pipe will create
a new magento project.

## Architecture
![image](https://user-images.githubusercontent.com/40108018/213162548-349aeb6a-fb87-4146-b903-ec30afcb32f5.png)


## Environment Variables

| Variable                | Usage                                                                                                                                                                                                          |
|-------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `TYPE`                  | Available tests are `integration`, `rest`, `graphql`. Default: `integration`                                                                                                                                   |
| `DATABASE_USERNAME`     | Default: `user`                                                                                                                                                                                                |
| `DATABASE_ROOTPASSWORD` | Default: `rootpassword`                                                                                                                                                                                        |
| `DATABASE_PASSWORD`     | Default: `password`                                                                                                                                                                                            |
| `ELASTICSEARCH_HOST`    | Must be `host.docker.internal` when running in pipelines. Optionally change this if you are developing the pipe locally.                                                                                       |
| `RABBITMQ_HOST`         | Must be `host.docker.internal` when running in pipelines. Optionally change this if you are developing the pipe locally.                                                                                       |
| `DATABASE_HOST`         | Must be `host.docker.internal` when running in pipelines. Optionally change this if you are developing the pipe locally.                                                                                       |
| `COMPOSER_AUTH`         | JSON stringified composer `auth.json` with the relevant configuration you need.                                                                                                                                |
| `REPOSITORY_URL`        | `https://repo.magento.com/` - If using this, make sure the `COMPOSER_AUTH` variable is set. <br>  `https://mirror.mage-os.org/` - Only supports open source edition. <br> Default: `https://repo.magento.com/` |
| `MAGENTO_VERSION`       | (Optional) Default: `magento/project-community-edition:>=2.4.6 <2.4.7` <br> Commerce: `magento/project-enterprise-edition:>=2.4.6 <2.4.7`                                                                      |
| `GROUP`                 | (Optional) Specify test group(s) to run. Example: `--group inventory,indexer_dimension` <br> See phpunit [@group annotation](https://phpunit.readthedocs.io/en/9.5/annotations.html#group)                     |
| `TESTS_PATH`            | (Optional) Specify a test path to run. Example `./app/code/The/Module`                                                                                                                                         |
| `COMPOSER_PACKAGES`     | (Optional) Specify any packages to require. Used when testing against a stand-alone module. Example `aligent/magento-async-events`                                                                             |
| `SKIP_DEPENDENCIES`     | (Optional) Skip installation of composer dependencies, if set this assumes you have performed `composer install` outside of the pipe.                                                                          |

## Using private packages
When you are testing a standalone module that has dependencies which are private, you may want to include private
registries or repositories so that the test pipeline can download the packages. The pipe provides support for this.

Include the `repositories` field in your module's `composer.json`. When the pipe creates a new magento project, it will
merge the module's `composer.json`'s `repositories`  field to the project's `composer.json`. You will also need
to make sure that the `COMPOSER_AUTH` variable includes credentials for the private registries.

## Example Pipeline
```yml
image: php:8.2

definitions:
  services:
    elasticsearch:
      image: magento/magento-cloud-docker-elasticsearch:7.11-1.3.2
      variables:
        ES_SETTING_DISCOVERY_TYPE: single-node
        ES_JAVA_OPTS: '-Xms512m -Xmx512m'

    mariadb:
      image: mariadb:10.6
      memory: 256
      variables:
        MYSQL_DATABASE: magento_integration_tests
        MYSQL_USER: user
        MYSQL_PASSWORD: password
        MYSQL_ROOT_PASSWORD: rootpassword

    rabbitmq:
      image: rabbitmq:3.11-management
      memory: 256
      env:
        RABBITMQ_DEFAULT_USER: guest
        RABBITMQ_DEFAULT_PASS: guest

  steps:
    - step: &integration
        name: "Integration Test"
        caches:
          - docker
        script:
          - pipe: docker://aligent/magento-integration-test-pipe
            variables:
              TYPE: integration
              TESTS_PATH: ../../../vendor/magento/magento2-base/dev/tests/integration/testsuite/Magento/Framework/MessageQueue/TopologyTest.php
              REPOSITORY_URL: https://mirror.mage-os.org/
              GROUP: --group group_a,group_b
        services: 
          - mariadb
          - elasticsearch
          - rabbitmq

    - step: &rest
        name: "REST API"
        caches:
          - docker
        script:
          - pipe: docker://aligent/magento-integration-test-pipe
            variables:
              TYPE: rest
              TESTS_PATH: vendor/magento/magento2-base/dev/tests/api-functional/testsuite/Magento/Directory/Api/CurrencyInformationAcquirerTest.php
              REPOSITORY_URL: https://mirror.mage-os.org/

        services: 
          - mariadb
          - elasticsearch
          - rabbitmq

    - step: &graphql
        name: "GraphQL"
        caches:
          - docker
        script:
          - pipe: docker://aligent/magento-integration-test-pipe
            variables:
              TYPE: graphql
              TESTS_PATH: vendor/magento/magento2-base/dev/tests/api-functional/testsuite/Magento/GraphQl/Directory/CurrencyTest.php
              REPOSITORY_URL: https://mirror.mage-os.org/

        services: 
          - mariadb
          - elasticsearch
          - rabbitmq

pipelines:
  branches:
    production:
      - parallel:
        - step: *integration
        - step: *rest
        - step: *graphql
```

## Contributing

Commits to the `main` branch will trigger an automated build for the latest tag in DockerHub, commits to the `dev`
branch will trigger an automated build with the `dev` tag in Docker hub.

A docker compose based environment is available to help develop the pipe locally.

## Local project testing

The docker compose environment can be run to test a project locally, without requiring a pull request. Simply follow these steps:

1. Checkout the project you would like to test to a working directory.
2. Open a terminal and set a `PROJECT_DIR` environment variable pointing to the project's directory. For example:

```shell
$ PROJECT_DIR=~/projects/my-test-project
```
3. Create one or more `.env` files within your project to set environment variables that need to be overridden (e.g. `GROUP`)
   *  Note that environment variables can be overridden by setting values in your shell directly. The use of `.env` files makes it easier to quickly change between types of tests, etc.
4. Start the environment, providing overridden environment variables or your custom `.env` file:

```shell
$ docker compose --env-file path/to/env_file up -d
$ docker compose --env-file path/to/env_file exec --workdir=/root/app magento sh
```

6. Make sure that `/pipe.sh` is executable.

```shell
/# chmod +x pipe.sh
```

7. Invoke the pipe

```shell
/# /pipe.sh
```
