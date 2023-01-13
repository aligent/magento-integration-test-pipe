#!/usr/bin/env sh

set -e

TYPE=${TYPE:="integration"}

run_integration_tests () {
  composer create-project --repository-url="https://mirror.mage-os.org/" "magento/project-community-edition:>=2.4.5 <2.4.6" ./magento2 --no-install
  cd magento2
  composer config --no-interaction allow-plugins.dealerdirect/phpcodesniffer-composer-installer true
  composer config --no-interaction allow-plugins.laminas/laminas-dependency-plugin true
  composer config --no-interaction allow-plugins.magento/* true
  cat composer.json
  composer install
  cd dev/tests/integration
  sed -i "s/'db-host' => 'localhost'/'db-host' => 'host.docker.internal'/" etc/install-config-mysql.php.dist
  sed -i "s/'db-user' => 'root'/'db-user' => 'user'/" etc/install-config-mysql.php.dist
  sed -i "s/'db-password' => '123123q'/'db-password' => 'password'/" etc/install-config-mysql.php.dist
  sed -i "s/'elasticsearch-host' => 'localhost'/'elasticsearch-host' => 'host.docker.internal'/" etc/install-config-mysql.php.dist
  sed -i "s/'amqp-host' => 'localhost'/'amqp-host' => 'host.docker.internal'/" etc/install-config-mysql.php.dist
  php ../../../vendor/bin/phpunit ../../../vendor/magento/magento2-base/dev/tests/integration/testsuite/Magento/Framework/MessageQueue/TopologyTest.php
}

run_rest_api_tests () {
  echo "Running rest api tests"
}

run_graphql_api_tests () {
  echo "Running graphql api tests"
}

case $TYPE in

  integration)
    run_integration_tests
    ;;

  rest-functional)
    run_rest_api_tests
    ;;

  graphql-functional)
    run_graphql_api_tests
    ;;

  *)
    echo -n "Unknown test type\n"
    ;;
esac
