# Tracking-Parking (tracking-parking-center)

現場のエッジデバイス（[device](https://github.com/NUTFes/tracking-parking)）が検出した駐車場の入出庫イベントを
API サーバーで受信・DB へ保存し、Web で可視化するセンター側システム。

このリポジトリ自体は **docker-compose・README・ドキュメントなどオーケストレーション層のみ**を
管理するポリレポ（multi-repo）構成。`services/` 配下の各サービス（api・web・admin-web・device）は
それぞれ独立したリポジトリで、このリポジトリの管理下には含まない（`.gitignore` で `services/` を
丸ごと対象外にしている）。各サービスの詳しい設計・開発手順は、それぞれのリポジトリのREADMEを参照。

## 構成

```
tracking-parking-center/        ← このリポジトリ（オーケストレーション層のみ）
├── services/                   ← git管理外（.gitignore）。各サービスは独立したリポジトリを個別にclone
│   ├── api/        FastAPI + MySQL — REST API、デバイス認証、コマンドキュー
│   ├── web/        React + Vite — 公開ビューア（各駐車場の空き台数を閲覧するだけの画面。操作は一切なし）
│   ├── admin-web/  React + Vite — 管理コンソール（駐車場・デバイスの登録、再起動などの操作）
│   └── device/     現場のエッジデバイス側実装（https://github.com/NUTFes/tracking-parking）。
│                    docker compose の起動対象外
└── docker-compose.yml
```

| サービス | リポジトリ | 詳細 |
|---|---|---|
| api | [tracking-parking-api](https://github.com/NUTFes/tracking-parking-api) | アーキテクチャ・認証設計・DBスキーマ・API仕様・バックエンド開発手順 |
| web | [tracking-parking-web](https://github.com/NUTFes/tracking-parking-web) | 公開ビューアのフロントエンド開発手順 |
| admin-web | [tracking-parking-admin-web](https://github.com/NUTFes/tracking-parking-admin-web) | 管理コンソールのフロントエンド開発手順・クライアント側認証の実装 |
| device | [tracking-parking](https://github.com/NUTFes/tracking-parking) | エッジデバイス側の実装（別チーム管理） |

`web`（空き状況の閲覧）と `admin-web`（登録・操作）を別サービスに分けているのは、閲覧用の画面を
不特定多数に公開しても、デバイス再起動のような操作系エンドポイントを誤って触れないようにするため。
`admin-web` はユーザー認証で保護されている（詳細は [api リポジトリのREADME](https://github.com/NUTFes/tracking-parking-api) 参照）。

## 初期セットアップ

### 前提ツール

- Docker / Docker Compose（これだけあれば起動できる）
- ローカルでフロントエンド/バックエンドを直接動かす場合のみ追加で必要:
  Node.js（`services/web`・`services/admin-web` の `package.json` 参照）、Python 3.12（`services/api`）

### 1. clone

このリポジトリと、動かしたい各サービスのリポジトリをそれぞれ `services/<サービス名>` に配置する。

```bash
git clone https://github.com/NUTFes/tracking-parking-center tracking-parking-center
cd tracking-parking-center

git clone https://github.com/NUTFes/tracking-parking-api services/api
git clone https://github.com/NUTFes/tracking-parking-web services/web
git clone https://github.com/NUTFes/tracking-parking-admin-web services/admin-web
git clone https://github.com/NUTFes/tracking-parking services/device
```

`device`（現場のエッジデバイス側実装）は `docker compose` の起動対象には含まれない（別環境で
個別に動かすもの）ので、API連携仕様を確認する参照用途が中心。いずれも `services/` ごと
`.gitignore` されているため、このリポジトリの `git status` / `git add` には影響しない。

### 2. `.env` の作成

```bash
cp .env.example .env
```

ローカル開発でDocker Composeから起動するだけなら既定値のままで動く。各変数の意味は
[設定一覧](#設定一覧)を参照。フロントエンドを `docker compose` 経由ではなく直接
`npm run dev` で動かす場合は `services/web/.env.example` ・ `services/admin-web/.env.example`
もそれぞれ `.env` としてコピーする（中身は `VITE_API_BASE_URL` のみ）。

### 3. 起動

```bash
docker compose up --build
```

- API: http://localhost:8000 （Swagger UI: http://localhost:8000/docs, ReDoc: http://localhost:8000/redoc）
- Web（公開ビューア）: http://localhost:5173
- Admin（管理コンソール）: http://localhost:5174
- MySQL: localhost:3306

`api` コンテナは起動時に `alembic upgrade head` を実行してスキーマを作成する。

### 4. 管理者アカウントの作成

Admin（管理コンソール）にログインするには先にアカウントが必要。

```bash
docker compose exec api python scripts/create_admin_user.py <username>
```

パスワードは対話プロンプトで入力する。詳細は [api リポジトリのREADME](https://github.com/NUTFes/tracking-parking-api) を参照。

### 設定一覧

`.env`（ルート、Docker Compose用）の変数一覧。カッコ内は既定値。

| 変数 | 対象 | 説明 |
|---|---|---|
| `TZ`（`Asia/Tokyo`） | 全コンテナ | コンテナのタイムゾーン。API/DBの時刻はこのタイムゾーンのnaive datetimeで統一 |
| `MYSQL_DATABASE`（`tracking_parking`） | db | 作成するデータベース名 |
| `MYSQL_ROOT_PASSWORD`（`root`） | db | MySQL rootユーザーのパスワード |
| `MYSQL_USER` / `MYSQL_PASSWORD`（`trapa` / `trapa_password`） | db | アプリ用DBユーザー。`DATABASE_URL` と揃える必要がある |
| `DATABASE_URL` | api | SQLAlchemyの接続文字列。`MYSQL_*` を変更したらここも合わせて変更する |
| `API_PORT`（`8000`） | api | ホスト側に公開するポート |
| `DEVICE_OFFLINE_THRESHOLD_SECONDS`（`120`） | api | 最終通信からこの秒数を超えるとデバイスをオフライン扱いにする |
| `CORS_ORIGINS`（`http://localhost:5173,http://localhost:5174`） | api | ブラウザからのアクセスを許可するオリジン（カンマ区切り）。`WEB_PORT`/`ADMIN_WEB_PORT`を変えたら合わせる |
| `JWT_SECRET`（`change-me-in-production`） | api | Adminアクセストークンの署名鍵。**本番では必ず固有の値に変更**（`openssl rand -hex 32`） |
| `ACCESS_TOKEN_EXPIRE_MINUTES`（`15`） | api | Adminアクセストークンの有効期限（分） |
| `REFRESH_TOKEN_EXPIRE_DAYS`（`14`） | api | Adminリフレッシュトークンの有効期限（日） |
| `COOKIE_SECURE`（`false`） | api | リフレッシュトークンCookieの `Secure` 属性。HTTPS配下でのみ `true` にできる |
| `WEB_PORT`（`5173`） | web | ホスト側に公開するポート |
| `ADMIN_WEB_PORT`（`5174`） | admin-web | ホスト側に公開するポート |
| `VITE_API_BASE_URL`（`http://localhost:8000`） | web, admin-web | フロントエンドが呼び出すAPIのベースURL。Viteのビルド時に埋め込まれる |

本番運用時の注意点（`JWT_SECRET`・`COOKIE_SECURE`など）の詳細は
[api リポジトリのREADME](https://github.com/NUTFes/tracking-parking-api) を参照。

### 動作確認の例

駐車場・デバイスの登録は Admin（http://localhost:5174）の画面から行うのが基本（先に
[管理者アカウントの作成](#4-管理者アカウントの作成) が必要）。curl で行う場合は以下の通り:

```bash
# ログインしてアクセストークンを取得
AT=$(curl -s -c cookies.txt -X POST localhost:8000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username": "<username>", "password": "<password>"}' | python3 -c "import json,sys;print(json.load(sys.stdin)['access_token'])")

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

登録後、Web（http://localhost:5173）で空き台数を確認できる。

## License

MIT License. 詳細は [LICENSE](LICENSE) を参照。
