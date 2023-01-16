#!/usr/bin/env sh

set -e

TYPE=${TYPE:="integration"}

# Database defaults
DATABASE_USERNAME=${DATABASE_USERNAME:="user"}
DATABASE_ROOTPASSWORD=${DATABASE_ROOTPASSWORD:="rootpassword"}

run_integration_tests () {
  if [ ! -f "composer.lock" ]; then
    echo "composer.lock does not exist."
    composer create-project --repository-url="https://mirror.mage-os.org/" "magento/project-community-edition:>=2.4.5 <2.4.6" ./magento2 --no-install
    cd magento2
  fi

  echo $COMPOSER_AUTH > ~/.composer/auth.json
  composer config --no-interaction allow-plugins.dealerdirect/phpcodesniffer-composer-installer true
  composer config --no-interaction allow-plugins.laminas/laminas-dependency-plugin true
  composer config --no-interaction allow-plugins.magento/* true
  cat composer.json
  composer install
  cd dev/tests/integration
  cat etc/install-config-mysql.php.dist
  sed -i "s/'db-host' => 'localhost'/'db-host' => 'host.docker.internal'/" etc/install-config-mysql.php.dist
  sed -i "s/'db-user' => 'root'/'db-user' => 'user'/" etc/install-config-mysql.php.dist
  sed -i "s/'db-password' => '123123q'/'db-password' => 'password'/" etc/install-config-mysql.php.dist
  sed -i "s/'elasticsearch-host' => 'localhost'/'elasticsearch-host' => 'host.docker.internal'/" etc/install-config-mysql.php.dist
  sed -i "s/'amqp-host' => 'localhost'/'amqp-host' => 'host.docker.internal'/" etc/install-config-mysql.php.dist
  php ../../../vendor/bin/phpunit ../../../vendor/magento/magento2-base/dev/tests/integration/testsuite/Magento/Framework/MessageQueue/TopologyTest.php
}

run_rest_api_tests () {
  if [ ! -f "composer.lock" ]; then
    echo "composer.lock does not exist."
    composer create-project --repository-url="https://mirror.mage-os.org/" "magento/project-community-edition:>=2.4.5 <2.4.6" ./magento2 --no-install
    cd magento2
  fi

  mysql -h host.docker.internal -uroot -p$DATABASE_ROOTPASSWORD -e "CREATE DATABASE IF NOT EXISTS magento_functional_tests;GRANT ALL ON magento_functional_tests.* TO '$DATABASE_USERNAME'@'%';FLUSH PRIVILEGES;SHOW DATABASES"

  echo $COMPOSER_AUTH > ~/.composer/auth.json
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

run_graphql_tests () {
  if [ ! -f "composer.lock" ]; then
    echo "composer.lock does not exist."
    composer create-project --repository-url="https://mirror.mage-os.org/" "magento/project-community-edition:>=2.4.5 <2.4.6" ./magento2 --no-install
    cd magento2
  fi

  mysql -h host.docker.internal -uroot -p$DATABASE_ROOTPASSWORD -e "CREATE DATABASE IF NOT EXISTS magento_graphql_tests;GRANT ALL ON magento_graphql_tests.* TO '$DATABASE_USERNAME'@'%';FLUSH PRIVILEGES;SHOW DATABASES"

  echo $COMPOSER_AUTH > ~/.composer/auth.json
  composer config --no-interaction allow-plugins.dealerdirect/phpcodesniffer-composer-installer true
  composer config --no-interaction allow-plugins.laminas/laminas-dependency-plugin true
  composer config --no-interaction allow-plugins.magento/* true
  cat composer.json
  composer install
  cd dev/tests/api-functional

  cp phpunit_graphql.xml.dist phpunit_graphql.xml
  cp config/install-config-mysql.php.dist config/install-config-mysql-graphql.php
  sed -i 's/name="TESTS_MAGENTO_INSTALLATION" value="disabled"/name="TESTS_MAGENTO_INSTALLATION" value="enabled"/' phpunit_graphql.xml
  sed -i 's#http://magento.url#http://127.0.0.1:8082/index.php/#' phpunit_graphql.xml
  sed -i 's/value="admin"/value="Test Webservice User"/' phpunit_graphql.xml
  sed -i 's/value="123123q"/value="Test Webservice API key"/' phpunit_graphql.xml
  sed -i 's,value="config/install-config-mysql.php",value="config/install-config-mysql-graphql.php",' phpunit_graphql.xml

  sed -i "s,http://localhost/,http://127.0.0.1:8082/index.php/," config/install-config-mysql-graphql.php
  sed -i "s/'db-host'                      => 'localhost'/'db-host' => 'host.docker.internal'/" config/install-config-mysql-graphql.php
  sed -i "s/'db-name'                      => 'magento_functional_tests'/'db-name' => 'magento_graphql_tests'/" config/install-config-mysql-graphql.php
  sed -i "s/'db-user'                      => 'root'/'db-user' => 'user'/" config/install-config-mysql-graphql.php
  sed -i "s/'db-password'                  => ''/'db-password' => 'password'/" config/install-config-mysql-graphql.php
  sed -i "s/'elasticsearch-host'           => 'localhost'/'elasticsearch-host' => 'host.docker.internal'/" config/install-config-mysql-graphql.php
  cd ../../../
  php -S 127.0.0.1:8082 -t ./pub/ ./phpserver/router.php &
  sleep 5
  vendor/bin/phpunit -c $(pwd)/dev/tests/api-functional/phpunit_graphql.xml vendor/magento/magento2-base/dev/tests/api-functional/testsuite/Magento/GraphQl/Directory/CurrencyTest.php
}

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
