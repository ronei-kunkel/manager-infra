#!/bin/bash

echo ""

### Copy .env.example to .env
if [ ! -e "backend/.env" ]; then
  cp backend/.env.example backend/.env
fi

### Set .env vars into shell session
export $(cat backend/.env)

### Show containers running
echo "Containers Already Running:"
if [ -z "$(docker ps -a --filter 'status=running' --format 'table {{.ID}} \t {{.Names }} \t {{.Status}}' | grep ish_)" ]; then
  echo "none"
  echo ""
else
  docker ps -a --filter 'status=running' --format 'table {{.ID}} \t {{.Names }} \t {{.Status}}' | grep ish_
  containers=$(docker ps -a --filter 'status=running' --format 'table {{.ID}} \t {{.Names }} \t {{.Status}}' | grep ish_)
  echo ""
fi

### Network
if [ -z "$(docker network ls -q -f name=ish_internal)" ]; then
  docker network create -d bridge ish_internal
  echo ""
fi

### RabbitMq
if [ "$(docker ps -q -f name=ish_rabbitmq)" ]; then
  echo ""
else
  chmod 777 -R $(pwd)/infra/queue
  chmod 777 -R $(pwd)/infra/config/rabbitmq
  chmod 777 -R $(pwd)/infra/logs/rabbitmq

  rm -rf $(pwd)/infra/queue/mnesia/
  rm -rf $(pwd)/infra/queue/.erlang.cookie
  rm -rf $(pwd)/infra/logs/rabbitmq/rabbit.log

  docker run --rm -d -v $(pwd)/infra/queue:/var/lib/rabbitmq -v $(pwd)/infra/config/rabbitmq/10-defaults.conf:/etc/rabbitmq/conf.d/10-defaults.conf -v $(pwd)/infra/logs/rabbitmq:/var/log/rabbitmq/ -p 5672:5672 -p 15672:15672 --name ish_rabbitmq --network ish_internal -e RABBITMQ_ERLANG_COOKIE=$Q_COOKIE -e RABBITMQ_DEFAULT_USER=$Q_USER -e RABBITMQ_DEFAULT_PASS=$Q_PASS rabbitmq:management
  echo ""
fi

### MariaDB
if [ "$(docker ps -q -f name=ish_mariadb)" ]; then
  echo ""
else
  docker run --rm -d -v $(pwd)/infra/database/:/var/lib/mysql/ -v $(pwd)/infra/logs/mysql:/var/log/mysql/ -p 3306:3306 --name ish_mariadb --network ish_internal -e MYSQL_ROOT_PASSWORD=$DB_PASSWORD -e MARIADB_ROOT_PASSWORD=$DB_PASSWORD -e MARIADB_PASSWORD=$DB_PASSWORD -e MARIADB_USER=$DB_USERNAME mariadb:11.0.2
  echo ""
fi

### php-swoole server running Manager project with hyperf framework
if [ "$(docker ps -q -f name=ish_hyperf)" ]; then
  echo ""
else
  docker run --rm -d -v $(pwd)/backend:/manager/backend --name ish_hyperf -w /manager/backend -p 9501:9501 --privileged -u root --network ish_internal -it --entrypoint sh hyperf/hyperf:8.2-alpine-v3.18-swoole -c "composer install && php ./bin/hyperf.php start"
  echo ""
fi

### node
if [ "$(docker ps -q -f name=ish_node)" ]; then
  echo ""
else
  docker run --rm -d -v $(pwd)/frontend:/manager/frontend -w /manager/frontend --network ish_internal --name ish_node -p 80:3000 -it --entrypoint sh node:21-alpine -c "npm install && npm run build && npm run generate && npm run start"
  echo ""
fi

### Show containers running
containers_last_verify=$(docker ps -a --filter 'status=running' --format 'table {{.ID}} \t {{.Names }} \t {{.Status}}' | grep ish_)
if [ "$containers" = "$containers_last_verify" ]; then
  echo "All containers running."
  echo ""
else
  echo "Containers running:"
  docker ps -a --filter "status=running" --format 'table {{.ID}} \t {{.Names}} \t {{.Status}}' | grep ish_
  echo ""
fi

### Show addresses
if [ "$(docker ps -q -f name=ish_node)" ]; then
  echo "Manager frontend are available on: http://localhost"
  echo ""
fi

if [ "$(docker ps -q -f name=ish_hyperf)" ]; then
  echo "Manager backend are available on: http://localhost:9501"
  echo ""
fi

if [ "$(docker ps -q -f name=ish_rabbitmq)" ]; then
  echo "Queue web interface are running on: http://localhost:15672"
  echo "User and pass are availiable on backend/.env file"
  echo ""
fi

if [ "$(docker ps -q -f name=ish_mariadb)" ]; then
  echo "Database, user, pass and port are availiable on backend/.env file"
  echo ""
fi

echo "Enjoy!"
echo ""


## NODE 21.2 - dev
# docker run --rm -v $(pwd):/frontend/manager -w /frontend/manager --network ish_internal --name ish_node -p 80:3000 -it --entrypoint sh node:21-alpine -c "npm run dev"
