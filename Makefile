.PHONY: mysql

mysql:
	docker exec -it trapa-db sh -c 'exec mysql -u"$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"'
