#!/usr/bin/env sh

set -e

TYPE=${TYPE:="integration"}

# Database defaults
DATABASE_USERNAME=${DATABASE_USERNAME:="user"}
DATABASE_ROOTPASSWORD=${DATABASE_ROOTPASSWORD:="rootpassword"}
DATABASE_PASSWORD=${DATABASE_PASSWORD:="password"}

# Service defaults
OPENSEARCH_HOST=${OPENSEARCH_HOST:="host.docker.internal"}
RABBITMQ_HOST=${RABBITMQ_HOST:="host.docker.internal"}
DATABASE_HOST=${DATABASE_HOST:="host.docker.internal"}

REPOSITORY_URL=${REPOSITORY_URL:="https://repo.magento.com/"}
MAGENTO_VERSION=${MAGENTO_VERSION:="magento/project-community-edition:>=2.4.6 <2.4.7"}

GROUP=${GROUP:=""}
TESTS_PATH=${TESTS_PATH:=""}

create_database_schema () {
  mysql -h $DATABASE_HOST -uroot -p$DATABASE_ROOTPASSWORD << SQL
  CREATE DATABASE IF NOT EXISTS $1;
  CREATE USER IF NOT EXISTS '$DATABASE_USERNAME'@'%' IDENTIFIED BY '$DATABASE_PASSWORD';
  GRANT ALL ON $1.* TO '$DATABASE_USERNAME'@'%';
  FLUSH PRIVILEGES;
SQL
}

composer_setup () {
  if [ ! -f "composer.lock" ]; then
      echo "composer.lock does not exist."
      composer create-project --repository-url="$REPOSITORY_URL" "$MAGENTO_VERSION" /magento2 --no-install
      cd /magento2
      composer config repositories.local path $BITBUCKET_CLONE_DIR
      composer require $COMPOSER_PACKAGES "@dev" --no-update
  fi

  composer config --no-interaction allow-plugins.dealerdirect/phpcodesniffer-composer-installer true
  composer config --no-interaction allow-plugins.laminas/laminas-dependency-plugin true
  composer config --no-interaction allow-plugins.magento/* true
}

run_integration_tests () {
  composer_setup
  cat composer.json
  composer install

  cd dev/tests/integration
  cat etc/install-config-mysql.php.dist
  sed -i "s/'db-host' => 'localhost'/'db-host' => '$DATABASE_HOST'/" etc/install-config-mysql.php.dist
  sed -i "s/'db-user' => 'root'/'db-user' => '$DATABASE_USERNAME'/" etc/install-config-mysql.php.dist
  sed -i "s/'db-password' => '123123q'/'db-password' => '$DATABASE_PASSWORD'/" etc/install-config-mysql.php.dist
  sed -i "s/'opensearch-host' => 'localhost'/'opensearch-host' => '$OPENSEARCH_HOST'/" etc/install-config-mysql.php.dist
  sed -i "s/'amqp-host' => 'localhost'/'amqp-host' => '$RABBITMQ_HOST'/" etc/install-config-mysql.php.dist

  # Add extra configuration not available in enterprise edition
  sed -i "/^];/i 'consumers-wait-for-messages' => '0'," etc/install-config-mysql.php.dist
  sed -i "/^];/i 'search-engine' => 'opensearch'," etc/install-config-mysql.php.dist
  sed -i "/^];/i 'opensearch-host' => '$OPENSEARCH_HOST'," etc/install-config-mysql.php.dist
  sed -i "/^];/i 'opensearch-port' => 9200," etc/install-config-mysql.php.dist
  sed -i "/^];/i 'opensearch-index-prefix' => 'magento_integration'," etc/install-config-mysql.php.dist
  cat etc/install-config-mysql.php.dist

  php ../../../vendor/bin/phpunit $GROUP $TESTS_PATH
}

run_rest_api_tests () {
  create_database_schema magento_functional_tests

  composer_setup
  cat composer.json
  composer install
  cd dev/tests/api-functional
  cp phpunit_rest.xml.dist phpunit_rest.xml
  cp config/install-config-mysql.php.dist config/install-config-mysql.php
  sed -i 's/name="TESTS_MAGENTO_INSTALLATION" value="disabled"/name="TESTS_MAGENTO_INSTALLATION" value="enabled"/' phpunit_rest.xml
  sed -i 's#http://magento.url#http://127.0.0.1:8082/index.php/#' phpunit_rest.xml
  sed -i 's/value="admin"/value="Test Webservice User"/' phpunit_rest.xml
  sed -i 's/value="123123q"/value="Test Webservice API key"/' phpunit_rest.xml

  cat config/install-config-mysql.php.dist
  sed -i "s,http://localhost/,http://127.0.0.1:8082/index.php/," config/install-config-mysql.php
  sed -i "s/'db-host'                      => 'localhost'/'db-host' => '$DATABASE_HOST'/" config/install-config-mysql.php
  sed -i "s/'db-user'                      => 'root'/'db-user' => '$DATABASE_USERNAME'/" config/install-config-mysql.php
  sed -i "s/'db-password'                  => ''/'db-password' => '$DATABASE_PASSWORD'/" config/install-config-mysql.php
  sed -i "s/'opensearch-host'           => 'localhost'/'opensearch-host' => '$OPENSEARCH_HOST'/" config/install-config-mysql.php
  sed -i "/^];/i 'opensearch-index-prefix' => 'magento_rest'," config/install-config-mysql.php
  cat config/install-config-mysql.php

  cd ../../../
  php -S 127.0.0.1:8082 -t ./pub/ ./phpserver/router.php &
  sleep 5
  vendor/bin/phpunit -c $(pwd)/dev/tests/api-functional/phpunit_rest.xml $GROUP $TESTS_PATH
}

run_graphql_tests () {
  create_database_schema magento_graphql_tests

  composer_setup
  cat composer.json
  composer install
  cd dev/tests/api-functional

  cp phpunit_graphql.xml.dist phpunit_graphql.xml
  cp config/install-config-mysql.php.dist config/install-config-mysql-graphql.php
  sed -i 's/name="TESTS_MAGENTO_INSTALLATION" value="disabled"/name="TESTS_MAGENTO_INSTALLATION" value="enabled"/' phpunit_graphql.xml
  sed -i 's#http://magento.url#http://127.0.0.1:8083/index.php/#' phpunit_graphql.xml
  sed -i 's/value="admin"/value="Test Webservice User"/' phpunit_graphql.xml
  sed -i 's/value="123123q"/value="Test Webservice API key"/' phpunit_graphql.xml
  sed -i 's,value="config/install-config-mysql.php",value="config/install-config-mysql-graphql.php",' phpunit_graphql.xml

  cat config/install-config-mysql.php.dist
  sed -i "s,http://localhost/,http://127.0.0.1:8083/index.php/," config/install-config-mysql-graphql.php
  sed -i "s/'db-host'                      => 'localhost'/'db-host' => '$DATABASE_HOST'/" config/install-config-mysql-graphql.php
  sed -i "s/'db-name'                      => 'magento_functional_tests'/'db-name' => 'magento_graphql_tests'/" config/install-config-mysql-graphql.php
  sed -i "s/'db-user'                      => 'root'/'db-user' => '$DATABASE_USERNAME'/" config/install-config-mysql-graphql.php
  sed -i "s/'db-password'                  => ''/'db-password' => '$DATABASE_PASSWORD'/" config/install-config-mysql-graphql.php
  sed -i "s/'opensearch-host'           => 'localhost'/'opensearch-host' => '$OPENSEARCH_HOST'/" config/install-config-mysql-graphql.php
  sed -i "/^];/i 'opensearch-index-prefix' => 'magento_graphql'," config/install-config-mysql-graphql.php
  cat config/install-config-mysql-graphql.php

  cd ../../../
  php -S 127.0.0.1:8083 -t ./pub/ ./phpserver/router.php &
  sleep 5
  vendor/bin/phpunit -c $(pwd)/dev/tests/api-functional/phpunit_graphql.xml $GROUP $TESTS_PATH
}

if [[ ! -z "${COMPOSER_AUTH}" ]]; then
  echo "Configuring composer credentials"
  echo $COMPOSER_AUTH > ~/.composer/auth.json
else
  echo "No composer credentials found. \n \n"
fi

case $TYPE in

  integration)
    run_integration_tests
    ;;

  rest)
    run_rest_api_tests
    ;;

  graphql)
    run_graphql_tests
    ;;

  *)
    echo -n "Unknown test type\n"
    ;;
esac
