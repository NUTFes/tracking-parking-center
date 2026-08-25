.PHONY: mysql deploy

mysql:
	docker exec -it trapa-db sh -c 'exec mysql -u"$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"'

# staging・production サーバー上でSSHして直接実行する（詳細はscripts/deploy.sh）
deploy:
	./scripts/deploy.sh
