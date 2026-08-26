.PHONY: mysql dev deploy

mysql:
	docker exec -it trapa-db sh -c 'exec mysql -u"$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"'

# ローカル開発用に起動する（.env.develop を明示的に読む）
dev:
	docker compose --env-file .env.develop up --build

# staging・production サーバー上でSSHして直接実行する（詳細はscripts/deploy.sh）
deploy:
	./scripts/deploy.sh
