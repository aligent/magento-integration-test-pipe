# Aligent Magento Integration and API Functional Testing Pipe

A bitbucket pipe for running Magento integration and api functional tests 

It is designed to be run parallelly so you can leverage bitbucket parallel steps. [Example pipeline](#example-pipeline)

The pipe detects a `composer.lock` file and installs packages. If no `composer.lock` file is found, the pipe will create
a new magento project.

## Architecture
![image](https://user-images.githubusercontent.com/40108018/213162548-349aeb6a-fb87-4146-b903-ec30afcb32f5.png)


## Environment Variables

| Variable              | Usage                                                                                                                                                      |
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `TYPE`                  | Available tests are `integration`, `rest`, `graphql`. Default: `integration`                                                       |
| `DATABASE_USERNAME`     | Default: `user`                                                                                                                                            |
| `DATABASE_ROOTPASSWORD` | Default: `rootpassword`                                                                                                                                    |
| `DATABASE_PASSWORD`     | Default: `password`                                                                                                                                        |
| `ELASTICSEARCH_HOST`    | Must be `host.docker.internal` when running in pipelines. Optionally change this if you are developing the pipe locally.                                   |
| `RABBITMQ_HOST`         | Must be `host.docker.internal` when running in pipelines. Optionally change this if you are developing the pipe locally.                                   |
| `DATABASE_HOST`         | Must be `host.docker.internal` when running in pipelines. Optionally change this if you are developing the pipe locally.                                   |
| `COMPOSER_AUTH`         | JSON stringified composer `auth.json` with the relevant configuration you need.                                                                            |
| `REPOSITORY_URL`        | `https://repo.magento.com/` - If using this, make sure the `COMPOSER_AUTH` variable is set. <br>  `https://mirror.mage-os.org/` - Only supports open source edition. <br> Default: `https://repo.magento.com/` |
| `MAGENTO_VERSION`       | (Optional) Default: `magento/project-community-edition:>=2.4.6 <2.4.7` <br> Commerce: `magento/project-enterprise-edition:>=2.4.6 <2.4.7`                                                                                  |
| `GROUP`                 | (Optional) Specify test group(s) to run. Example: `--group inventory,indexer_dimension` <br> See phpunit [@group annotation](https://phpunit.readthedocs.io/en/9.5/annotations.html#group)                                                                    |
| `TESTS_PATH`            | (Optional) Specify a test path to run. Example `./app/code/The/Module`                                                                                     |

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

To start the environment simply run and exec into the magento container

```shell
$ docker compose up -d
$ docker compose exec magento sh
```

Make sure that `/pipe.sh` is executable.

```shell
/# chmod +x pipe.sh
```

Invoke the pipe overriding any environment variable as necessary

```shell
/# ./pipe.sh
/# TYPE=rest    ./pipe.sh
/# TYPE=graphql ./pipe.sh
```
