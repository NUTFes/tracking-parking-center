# Tracking-Parking (tracking-parking-center)

現場のエッジデバイス（[device](https://github.com/NUTFes/tracking-parking)）が検出した駐車場の入出庫イベントを
API サーバーで受信・DB へ保存し、Web で可視化するセンター側システム。

このリポジトリ自体は **docker-compose・README・ドキュメントなどオーケストレーション層のみ**を
管理するポリレポ（multi-repo）構成。`services/` 配下の各サービス（api・web・manager・admin-web・device）は
それぞれ独立したリポジトリで、このリポジトリの管理下には含まない（`.gitignore` で `services/` を
丸ごと対象外にしている）。各サービスの詳しい設計・開発手順は、それぞれのリポジトリのREADMEを参照。

## 構成

```
tracking-parking-center/        ← このリポジトリ（オーケストレーション層のみ）
├── services/                   ← git管理外（.gitignore）。各サービスは独立したリポジトリを個別にclone
│   ├── api/        FastAPI + MySQL — REST API、デバイス認証、コマンドキュー
│   ├── web/        React + Vite — 公開ビューア（各駐車場の台数を閲覧するだけの画面。ログイン不要・操作は一切なし）
│   ├── manager/     React + Vite — 駐車場管理者コンソール（サインインした人だけ台数を手動増減）
│   ├── admin-web/  React + Vite — 管理コンソール（駐車場・デバイスの登録、削除、リセットなどの操作）
│   └── device/     現場のエッジデバイス側実装（https://github.com/NUTFes/tracking-parking）。
│                    docker compose の起動対象外
├── docker-compose.yml       ← ローカル開発用
├── docker-compose.prod.yml  ← staging・production共通（デプロイ参照）
└── scripts/deploy.sh        ← staging・productionサーバー上で実行するデプロイスクリプト
```

| サービス | リポジトリ | 詳細 |
|---|---|---|
| api | [tracking-parking-api](https://github.com/NUTFes/tracking-parking-api) | アーキテクチャ・認証設計・DBスキーマ・API仕様・バックエンド開発手順 |
| web | [tracking-parking-web](https://github.com/NUTFes/tracking-parking-web) | 公開ビューアのフロントエンド開発手順 |
| manager | [tracking-parking-manager](https://github.com/NUTFes/tracking-parking-manager) | 駐車場管理者コンソールのフロントエンド開発手順・クライアント側認証の実装 |
| admin-web | [tracking-parking-admin-web](https://github.com/NUTFes/tracking-parking-admin-web) | 管理コンソールのフロントエンド開発手順・クライアント側認証の実装 |
| device | [tracking-parking](https://github.com/NUTFes/tracking-parking) | エッジデバイス側の実装（別チーム管理） |

3段階の権限に分かれている:

- **web**（公開ビューア）: ログイン不要、閲覧のみ。不特定多数に公開しても操作系エンドポイントに
  誤って触れる心配がない。
- **manager**（駐車場管理者）: 実行委員のGoogleアカウント（`NN.x.姓.nutfes@gmail.com`形式、承認リスト
  不要）でサインインすると使える。各駐車場の台数を手動増減できるだけで、駐車場・デバイスの登録や
  削除はできない。
- **admin-web**（管理者）: あらかじめ許可したGoogleアカウントのみ（承認リストあり）。駐車場・
  デバイスの登録／編集／削除、台数のリセット、デバイス再起動など、強い操作権限を持つ。

認証設計の詳細は [api リポジトリのREADME](https://github.com/NUTFes/tracking-parking-api) を参照。

## 初期セットアップ

### 前提ツール

- Docker / Docker Compose（これだけあれば起動できる）
- ローカルでフロントエンド/バックエンドを直接動かす場合のみ追加で必要:
  Node.js（`services/web`・`services/manager`・`services/admin-web` の `package.json` 参照）、Python 3.12（`services/api`）

### 1. clone

このリポジトリと、動かしたい各サービスのリポジトリをそれぞれ `services/<サービス名>` に配置する。

```bash
git clone https://github.com/NUTFes/tracking-parking-center tracking-parking-center
cd tracking-parking-center

git clone https://github.com/NUTFes/tracking-parking-api services/api
git clone https://github.com/NUTFes/tracking-parking-web services/web
git clone https://github.com/NUTFes/tracking-parking-manager services/manager
git clone https://github.com/NUTFes/tracking-parking-admin-web services/admin-web
git clone https://github.com/NUTFes/tracking-parking services/device
```

`device`（現場のエッジデバイス側実装）は `docker compose` の起動対象には含まれない（別環境で
個別に動かすもの）ので、API連携仕様を確認する参照用途が中心。いずれも `services/` ごと
`.gitignore` されているため、このリポジトリの `git status` / `git add` には影響しない。

### 2. `.env.develop` の作成

staging・production用の `.env.staging` / `.env.production`（後述の「デプロイ（ステージング／本番）」
セクション参照）と並べたときに紛らわしくならないよう、ローカル開発用は `.env.develop` という名前にしている
（`docker compose` はこの名前を自動では読まないため、起動時は毎回 `--env-file .env.develop`
を明示するか、後述の `make dev` を使う）。

```bash
cp .env.develop.example .env.develop
```

ローカル開発でDocker Composeから起動するだけなら既定値のままで動く。各変数の意味は
[設定一覧](#設定一覧)を参照。

### 3. 起動

```bash
docker compose --env-file .env.develop up --build
# または
make dev
```

- API: http://localhost:8000 （Swagger UI: http://localhost:8000/docs, ReDoc: http://localhost:8000/redoc）
- Web（公開ビューア）: http://localhost:5173
- Manager（駐車場管理者）: http://localhost:5175
- Admin（管理コンソール）: http://localhost:5174
- MySQL: localhost:3306

`api` コンテナは起動時に `alembic upgrade head` を実行してスキーマを作成する。

### 4. Google OAuthクライアントIDの設定

Manager/AdminともログインはGoogle Sign-Inを使う。Google Cloud ConsoleでOAuthクライアント
（Webアプリケーション種別、承認済みJavaScript生成元にhttp://localhost:5174とhttp://localhost:5175を追加。
`web`はログイン機能自体を持たないため追加不要）を作成し、`.env.develop` の `GOOGLE_CLIENT_ID` /
`VITE_GOOGLE_CLIENT_ID` に同じ値を設定する。このクライアントはstaging・productionとも
共有する（デプロイ先のドメインを承認済みJavaScript生成元に追加するだけで、クライアントID
自体は使い回す。詳細はデプロイ手順を参照）。

### 5. 管理者アカウントの許可リスト登録

Admin（管理コンソール）にログインできるのは、あらかじめ許可したGoogleアカウント（実行委員の
`NN.x.姓.nutfes@gmail.com` 形式のみ）だけ。Manager（駐車場管理者コンソール）は許可リスト不要
（フォーマットが正しいアカウントなら誰でもログインできる）なので、この登録は不要。

`25.m.kitano.nutfes@gmail.com` は最初の起動時（`api`コンテナの起動コマンド、`docker-compose.yml`
参照）に自動で許可リストへ登録される。dev・staging・productionすべて共通で、既に登録済みなら
何もしない（べき等）ので、初回セットアップとしてはこれで完了 — このアカウントでAdminに
ログインし、他の実行委員は管理コンソールの画面から追加していけばよい。

CLIで追加・削除したい場合（このアカウント自体が使えなくなった場合の復旧など）は:

```bash
docker compose exec api python scripts/manage_admin_allowlist.py add 25.m.kitano.nutfes@gmail.com
```

詳細は [api リポジトリのREADME](https://github.com/NUTFes/tracking-parking-api) を参照。

### 設定一覧

`.env.develop`（ルート、ローカル開発のDocker Compose用）の変数一覧。カッコ内は既定値。

| 変数 | 対象 | 説明 |
|---|---|---|
| `TZ`（`Asia/Tokyo`） | 全コンテナ | コンテナのタイムゾーン。API/DBの時刻はこのタイムゾーンのnaive datetimeで統一 |
| `MYSQL_DATABASE`（`tracking_parking`） | db | 作成するデータベース名 |
| `MYSQL_ROOT_PASSWORD`（`root`） | db | MySQL rootユーザーのパスワード |
| `MYSQL_USER` / `MYSQL_PASSWORD`（`trapa` / `trapa_password`） | db | アプリ用DBユーザー。`DATABASE_URL` と揃える必要がある |
| `DATABASE_URL` | api | SQLAlchemyの接続文字列。`MYSQL_*` を変更したらここも合わせて変更する |
| `API_PORT`（`8000`） | api | ホスト側に公開するポート |
| `DEVICE_OFFLINE_THRESHOLD_SECONDS`（`120`） | api | 最終通信からこの秒数を超えるとデバイスをオフライン扱いにする |
| `CORS_ORIGINS`（`http://localhost:5173,http://localhost:5174,http://localhost:5175`） | api | ブラウザからのアクセスを許可するオリジン（カンマ区切り）。各`*_PORT`を変えたら合わせる |
| `GOOGLE_CLIENT_ID` | api | Google Sign-InのOAuthクライアントID。Manager・AdminどちらのIDトークン検証にも使う |
| `VITE_GOOGLE_CLIENT_ID` | manager, admin-web | 同上（フロントエンド用。`GOOGLE_CLIENT_ID`と同じ値にする） |
| `JWT_SECRET`（`change-me-in-production`） | api | Adminアクセストークンの署名鍵。**本番では必ず固有の値に変更**（`openssl rand -hex 32`） |
| `ACCESS_TOKEN_EXPIRE_MINUTES`（`15`） | api | Adminアクセストークンの有効期限（分） |
| `REFRESH_TOKEN_EXPIRE_DAYS`（`14`） | api | Adminリフレッシュトークンの有効期限（日） |
| `COOKIE_SECURE`（`false`） | api | リフレッシュトークンCookieの `Secure` 属性。HTTPS配下でのみ `true` にできる |
| `WEB_PORT`（`5173`） | web | ホスト側に公開するポート |
| `MANAGER_PORT`（`5175`） | manager | ホスト側に公開するポート |
| `ADMIN_WEB_PORT`（`5174`） | admin-web | ホスト側に公開するポート |
| `VITE_API_BASE_URL`（`http://localhost:8000`） | web, manager, admin-web | フロントエンドが呼び出すAPIのベースURL。Viteのビルド時に埋め込まれる |

本番運用時の注意点（`JWT_SECRET`・`COOKIE_SECURE`など）の詳細は
[api リポジトリのREADME](https://github.com/NUTFes/tracking-parking-api) を参照。

### 動作確認の例

駐車場・デバイスの登録は Admin（http://localhost:5174）の画面から行うのが基本（先に
[Google OAuthクライアントIDの設定](#4-google-oauthクライアントidの設定)と
[許可リスト登録](#5-管理者アカウントの許可リスト登録)が必要）。ログインはブラウザでのGoogle
Sign-Inが前提のため、curlで一連の動作を試す場合はAdminにログインした状態のブラウザの開発者
ツール（Network タブなどでAT/Cookieを確認）からアクセストークンを取得して使う:

```bash
AT="<Adminにログイン後、ブラウザの開発者ツールから取得したアクセストークン>"

# 駐車場を登録（要ログイン）
curl -X POST localhost:8000/api/v1/parking-lots \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $AT" \
  -d '{"name": "第一駐車場", "capacity": 50}'

# デバイスを登録（api_key はレスポンスでのみ取得可能、要ログイン）
curl -X POST localhost:8000/api/v1/devices \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $AT" \
  -d '{"device_code": "trapa-dev1", "parking_lot_id": 1}'

# 入庫イベントを登録（デバイスのAPIキーで認証、ログイン不要）
curl -X POST localhost:8000/api/v1/events \
  -H 'Content-Type: application/json' -H 'X-API-Key: <上で取得したapi_key>' \
  -d '{"event_type": "entry", "detected_at": "2026-08-14T10:00:00"}'
```

登録後、Web（http://localhost:5173）で台数を確認できる。台数の手動増減はManager
（http://localhost:5175）でGoogleサインインすれば操作できる（許可リストは不要、実行委員の
メール形式であれば誰でも可）。

## デプロイ（ステージング／本番）

staging・productionはそれぞれ独立したサーバー（VPS等）1台ずつで動かす。両サーバーとも
このリポジトリ＋`services/*`の各リポジトリを配置し、同じ `docker-compose.prod.yml` を使う
（内容は環境ごとに置く `.env` の値だけで変わる）。ローカル開発用の `docker-compose.yml`
との違い:

- ソースをbind mountせず、`docker compose build` 時にイメージへ焼き込む
- フロントエンド（web/manager/admin-web）はViteの開発サーバーではなく、`npm run build`
  した静的ファイルをnginxで配信する本番用イメージ（各サービスの `Dockerfile.prod`）を使う
- どのポートもインターネットには直接公開しない。外部公開は [Cloudflare
  Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
  経由（`cloudflared` コンテナがcompose内部ネットワーク経由で各サービスにアクセスし、
  トンネル越しにHTTPS公開する）。ホスト側に公開されるのは `127.0.0.1` 宛のポートのみ
  （SSHポートフォワードでのデバッグ用）

### 1. サーバーの準備

各サーバー（staging用・production用）で、[初期セットアップ](#初期セットアップ)の手順1と
同様にこのリポジトリと `services/api`・`services/web`・`services/manager`・
`services/admin-web` をcloneする（`services/device` は不要）。Docker / Docker Composeが
使えること。

### 2. Cloudflare Tunnelの作成

環境ごとに（staging用・production用で別々に）[Cloudflare Zero Trust
ダッシュボード](https://one.dash.cloudflare.com/)でTunnelを1つ作成し、公開ホスト名を
4つ、それぞれ内部サービスへのingressとして設定する（ポートはこのリポジトリの
`docker-compose.prod.yml` に合わせる）。staging用ドメインには `stg.` プレフィックスを
付ける:

| 公開ホスト名（production） | 公開ホスト名（staging） | 転送先 |
|---|---|---|
| `app.trapa.nutfes.net` | `stg.app.trapa.nutfes.net` | `http://web:80` |
| `manager.trapa.nutfes.net` | `stg.manager.trapa.nutfes.net` | `http://manager:80` |
| `admin.trapa.nutfes.net` | `stg.admin.trapa.nutfes.net` | `http://admin-web:80` |
| `api.trapa.nutfes.net` | `stg.api.trapa.nutfes.net` | `http://api:8000` |

Dockerでのインストールコマンドに含まれるトンネルトークン（`--token` の値）を、次の手順で
`.env` の `CLOUDFLARE_TUNNEL_TOKEN` に設定する。

### 3. `.env` の作成

`.env.staging` / `.env.production`（実際の値入り、gitignore対象）をリポジトリ直下に
用意済み。デプロイ時は該当する方をそのサーバーへ転送し、`.env` としてコピーして使う:

```bash
# staging サーバー
cp .env.staging .env

# production サーバー
cp .env.production .env
```

（テンプレートのみの `.env.staging.example` / `.env.production.example` はコミット済みで、
値を1から作り直す場合の参照用。）`MYSQL_ROOT_PASSWORD` / `MYSQL_PASSWORD` / `JWT_SECRET` は
staging・productionで別々の値を生成済み。`GOOGLE_CLIENT_ID` / `VITE_GOOGLE_CLIENT_ID` は
ローカル開発（`.env.develop`）と同じクライアントIDを設定済み — ただしGCP側での
「承認済みJavaScript生成元」への追加はまだなので、Google Cloud Consoleでこのクライアントに
`manager.trapa.nutfes.net` / `admin.trapa.nutfes.net` / `stg.manager.trapa.nutfes.net` /
`stg.admin.trapa.nutfes.net` の4つを追加する必要がある（追加するまで該当ドメインでの
ログインは失敗する）。`CLOUDFLARE_TUNNEL_TOKEN` も、Tunnel作成後にインフラ担当が設定する。

### 4. デプロイ

```bash
./scripts/deploy.sh
# または
make deploy
```

`services/*` を `git pull` してから `docker compose -f docker-compose.prod.yml --env-file
.env up -d --build` する。2回目以降のデプロイも同じコマンドでよい。ログは
`docker compose -f docker-compose.prod.yml logs -f <サービス名>` で確認する。

### 5. 管理者アカウントの許可リスト登録（デプロイ環境）

[ローカルの手順](#5-管理者アカウントの許可リスト登録)と同じく、`25.m.kitano.nutfes@gmail.com`は
`api`起動時に自動で登録される（`docker-compose.prod.yml`参照）ので、追加の作業は不要。このアカウントで
Adminにログインし、他の実行委員は管理コンソールから追加する。

CLIで追加・削除したい場合は`-f docker-compose.prod.yml --env-file .env`を付ける:

```bash
docker compose -f docker-compose.prod.yml --env-file .env exec api \
  python scripts/manage_admin_allowlist.py add 25.m.kitano.nutfes@gmail.com
```

### 運用メモ

- DBのバックアップ（`mysqldump`の定期実行など）はこのリポジトリには含まれていない。
  必要に応じて別途cron等で用意する
- MySQLの一時ファイル肥大化・ディスク容量など、長期運用時の監視は運用者側の責任

## License

MIT License. 詳細は [LICENSE](LICENSE) を参照。
