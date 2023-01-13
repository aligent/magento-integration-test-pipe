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
  mysql -h mariadb -uroot -prootpassword -e "show databases;CREATE DATABASE IF NOT EXISTS magento_functional_tests;GRANT ALL ON magento_functional_tests.* TO 'user'@'%';FLUSH PRIVILEGES;"
  composer create-project --repository-url="https://mirror.mage-os.org/" "magento/project-community-edition:>=2.4.5 <2.4.6" ./magento2 --no-install
  cd magento2
  composer config --no-interaction allow-plugins.dealerdirect/phpcodesniffer-composer-installer true
  composer config --no-interaction allow-plugins.laminas/laminas-dependency-plugin true
  composer config --no-interaction allow-plugins.magento/* true
  cat composer.json
  composer install
  cd dev/tests/api-functional

  cp phpunit_rest.xml.dist phpunit_rest.xml
  cp config/install-config-mysql.php.dist config/install-config-mysql.php
  sed -i 's/name="TESTS_MAGENTO_INSTALLATION" value="disabled"/name="TESTS_MAGENTO_INSTALLATION" value="enabled"/' phpunit_rest.xml
  sed -i 's#http://magento.url#http://127.0.0.1:8082/index.php/#' phpunit_rest.xml
  sed -i 's/value="admin"/value="Test Webservice User"/' phpunit_rest.xml
  sed -i 's/value="123123q"/value="Test Webservice API key"/' phpunit_rest.xml

  sed -i "s,http://localhost/,http://127.0.0.1:8082/index.php/," config/install-config-mysql.php
  sed -i "s/'db-host'                      => 'localhost'/'db-host' => 'host.docker.internal'/" config/install-config-mysql.php
  sed -i "s/'db-user'                      => 'root'/'db-user' => 'user'/" config/install-config-mysql.php
  sed -i "s/'db-password'                  => ''/'db-password' => 'password'/" config/install-config-mysql.php
  sed -i "s/'elasticsearch-host'           => 'localhost'/'elasticsearch-host' => 'host.docker.internal'/" config/install-config-mysql.php
  cd ../../../
  php -S 127.0.0.1:8082 -t ./pub/ ./phpserver/router.php &
  sleep 5
  vendor/bin/phpunit -c $(pwd)/dev/tests/api-functional/phpunit_rest.xml vendor/magento/magento2-base/dev/tests/api-functional/testsuite/Magento/Directory/Api/CurrencyInformationAcquirerTest.php
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
