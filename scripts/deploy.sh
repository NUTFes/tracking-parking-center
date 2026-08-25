#!/usr/bin/env bash
# staging・production それぞれのサーバー上でSSHして直接実行するデプロイスクリプト。
# どちらの環境かはスクリプトの引数ではなく、そのサーバーに置いてある .env の
# 中身（ドメイン・シークレットなど）で決まる — 同じ docker-compose.prod.yml を
# staging機・production機の両方でそのまま使う想定。
#
# 前提:
#   - services/{api,web,manager,admin-web} が README の手順で clone 済み
#   - このリポジトリ直下に .env が用意済み（.env.staging.example または
#     .env.production.example をコピーして値を埋めたもの）
#
# 使い方: このリポジトリのルートで実行する
#   ./scripts/deploy.sh

set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "エラー: .env が見つかりません。.env.staging.example か .env.production.example を" >&2
  echo "  .env としてコピーし、値を埋めてから実行してください。" >&2
  exit 1
fi

for svc in api web manager admin-web; do
  echo "==> services/$svc を更新"
  git -C "services/$svc" pull --ff-only
done

echo "==> ビルドして起動"
docker compose -f docker-compose.prod.yml --env-file .env up -d --build --remove-orphans

echo "==> 未使用イメージを削除"
docker image prune -f

echo "==> 完了。ログ確認: docker compose -f docker-compose.prod.yml logs -f"
