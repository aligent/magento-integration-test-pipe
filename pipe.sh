#!/usr/bin/env ash

set -e

composer --version
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
