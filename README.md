# トラパ 駐車場管理センター (tracking-parking-center)

現場のエッジデバイス（[device](https://github.com/NUTFes/tracking-parking)）が検出した駐車場の入出庫イベントを
API サーバーで受信・DB へ保存し、Web で可視化するセンター側システム。

このリポジトリ自体は **docker-compose・README・ドキュメントなどオーケストレーション層のみ**を
管理するポリレポ（multi-repo）構成。`services/` 配下の各サービス（api・web・admin-web・device）は
それぞれ独立したリポジトリで、このリポジトリの管理下には含まない（`.gitignore` で `services/` を
丸ごと対象外にしている）。クローン・配置の手順は[初期セットアップ](#初期セットアップ)を参照。

## 構成

```
tracking-parking-center/        ← このリポジトリ（オーケストレーション層のみ）
├── services/                   ← git管理外（.gitignore）。各サービスは独立したリポジトリを個別にclone
│   ├── api/     FastAPI + MySQL — REST API、デバイス認証、コマンドキュー
│   ├── web/     React + Vite — 公開ビューア（各駐車場の空き台数を閲覧するだけの画面。操作は一切なし）
│   ├── admin-web/ React + Vite — 管理コンソール（駐車場・デバイスの登録、再起動などの操作）
│   └── device/  現場のエッジデバイス側実装（https://github.com/NUTFes/tracking-parking）。
│                Raspberry Pi上で動作する物体検出・録画処理など。docker compose の起動対象外
└── docker-compose.yml
```

`web`（空き状況の閲覧）と `admin-web`（登録・操作）を別サービスに分けているのは、閲覧用の画面を
不特定多数に公開しても、デバイス再起動のような操作系エンドポイントを誤って触れないようにするため。
`admin-web` はユーザー認証で保護されている（詳細は [Admin認証](#admin認証) 参照）。

## 初期セットアップ

### 前提ツール

- Docker / Docker Compose（これだけあれば起動できる）
- ローカルでフロントエンド/バックエンドを直接動かす場合のみ追加で必要:
  Node.js（`services/web`・`services/admin-web` の `package.json` 参照）、Python 3.12（`services/api`）

### 1. clone

このリポジトリと、動かしたい各サービスのリポジトリをそれぞれ `services/<サービス名>` に配置する。

```bash
git clone <このリポジトリのURL> tracking-parking-center
cd tracking-parking-center

git clone <api リポジトリのURL> services/api
git clone <web リポジトリのURL> services/web
git clone <admin-web リポジトリのURL> services/admin-web
git clone https://github.com/NUTFes/tracking-parking services/device
```

- `api` / `web` / `admin-web` は現時点ではまだ専用リポジトリに分離されていない（このリポジトリ内で
  開発してきたものを分離する想定）。分離済みなら上記コマンドのURLを埋めて実行し、未分離なら
  分離後にこのREADMEへリポジトリURLを追記すること。
- `device`（現場のエッジデバイス側実装。Raspberry Pi上で動作する物体検出・録画処理など）は
  [NUTFes/tracking-parking](https://github.com/NUTFes/tracking-parking) の実リポジトリで、
  すぐにcloneできる。`docker compose` の起動対象には含まれない（別環境で個別に動かすもの）ので、
  API連携仕様を確認する参照用途が中心。
- いずれも `services/` ごと `.gitignore` されているため、このリポジトリの `git status` / `git add`
  には影響しない。

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

Admin（管理コンソール）にログインするには先にアカウントが必要。手順は
[管理者アカウントの作成](#管理者アカウントの作成)を参照。

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

本番運用時に変更が必要な項目の詳細は[本番運用時の注意](#本番運用時の注意)を参照。

### 動作確認の例

駐車場・デバイスの登録は Admin（http://localhost:5174）の画面から行うのが基本（先に
[管理者アカウントの作成](#管理者アカウントの作成) が必要）。curl で行う場合は以下の通り:

```bash
# ログインしてアクセストークンを取得（リフレッシュトークンは-cでファイルに保存したcookieに乗る）
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

## APIのレイヤー構成

`services/api/app/` は責務ごとに以下の層へ分離している。依存の向きは常に上から下の一方向
（routers → usecases → repositories → models）で、逆向きの参照はない。

```
routers/      HTTPの窓口。リクエスト/レスポンスの型変換とOpenAPIアノテーション（summary・
              docstring・Field description）だけを持つ薄い層。業務ロジックやSQLは書かない。
usecases/     業務ロジック。トランザクション境界（db.commit()）はここが持つ。FastAPIに
              依存しないので単体テストしやすい。異常系は例外（app/exceptions.py）で表現する。
repositories/ DBアクセスのみ。SQLAlchemyのクエリはこの層に閉じ込め、業務的な意味づけはしない。
models/       SQLAlchemyのORMモデル（テーブル定義そのもの）。
schemas/      Pydanticのリクエスト/レスポンスDTO（OpenAPIスキーマの元）。
```

- **例外の流れ**: usecase が `NotFoundError` / `UnauthorizedError`（`app/exceptions.py`）を送出し、
  `main.py` に登録したグローバル例外ハンドラが404/401のHTTPレスポンスに変換する。router 自身は
  try/exceptを書かない（`routers/auth.py` の `refresh` だけ、Cookie削除という副作用のために例外を
  一度捕まえて再送出している）。
- **認証まわりの例外**: `deps.py`（`get_current_device` / `get_current_admin_user`）はFastAPIの
  `Depends` として動く都合上、`HTTPException` を直接送出する。ここだけはフレームワーク非依存に
  こだわらず、リクエストの認証解決という性質上FastAPI前提のコードとして割り切っている。
- **ヘルスチェック**（`routers/health.py`）は `SELECT 1` を打つだけで特定のモデルに紐づかないため、
  repository/usecase層を経由せずrouterで直接実行している（層分けのための層分けをしない）。

## エッジデバイス連携の設計方針（ポーリング方式）

現場のエッジデバイスは NAT 配下にあり、サーバー側から直接アクセスできないことが多い。
そのため「サーバーヘルスチェック」以外の全ての通信はエッジデバイス発でシンプルな REST
API のみで完結させている。

- **入出庫登録**: エッジデバイスが `POST /api/v1/events` を都度呼び出す。
- **デバイスのヘルスチェック**: エッジデバイスが定期的に `POST /api/v1/heartbeat` を呼び、
  サーバーは最終通信時刻を記録する。一定時間（`DEVICE_OFFLINE_THRESHOLD_SECONDS`）通信が
  なければオフライン扱いになる。
- **デバイスの再起動**: Web / 管理者が `POST /api/v1/devices/{id}/commands` でコマンドを
  キューに積む。エッジデバイスは次の `heartbeat` 呼び出しのレスポンスでコマンドを受け取り、
  実行後に `POST /api/v1/commands/{id}/ack` で結果を報告する。サーバーからデバイスへの
  直接プッシュは行わない。

この設計により、追加のインフラ（VPN・SSH トンネル等）なしに API サーバーと DB だけで
双方向のデバイス管理が成立する（リアルタイム性はハートビート間隔に依存する）。

## デバイス認証

エッジデバイスは `X-API-Key` ヘッダーでリクエストする。API キーはデバイス登録時
（`POST /api/v1/devices`）に一度だけ平文で返却され、サーバーには SHA-256 ハッシュのみ
保存される。デバイス自身は自分の DB 上の ID を知る必要はなく、API キーだけで
自分自身の登録済みリソースにアクセスできる。

## Admin認証

`admin-web` のユーザー認証は アクセストークン（AT）+ リフレッシュトークン（RT）方式。

- **AT**: 短命（既定15分）なJWT。`Authorization: Bearer <AT>` で送る。フロントエンドは
  **メモリ上（JSのモジュール変数）にのみ保持**し、localStorageやCookieなど永続化できる
  場所には一切書き込まない。ページをリロードするとATは消える。
- **RT**: 長命（既定14日）なランダムトークン。サーバーはそのSHA-256ハッシュのみをDB
  （`admin_refresh_tokens`）に保存する。フロントエンドからはJSで一切参照できない
  **HTTP Only Cookie**（`/api/v1/auth` パスのみに送信、`SameSite=Lax`）としてのみ
  やり取りする。使用するたびにローテーション（使い捨て）し、ログアウトや期限切れで
  失効する。
- ページを開いたとき、フロントエンドはATを持っていない（メモリがリセットされている）
  ため、まず `POST /api/v1/auth/refresh` をCookie任せで呼び、RTが有効ならATを再発行して
  ログイン状態を復元する（サイレントログイン）。RTが無い/失効していればログイン画面を表示する。
- 通常のAPIリクエストがAT切れで401になった場合、フロントエンドが自動的に一度だけ
  `/auth/refresh` を呼んでATを取り直し、元のリクエストをリトライする（`services/admin-web/src/api/client.ts`）。

保護範囲: `POST /parking-lots`、`GET /parking-lots/{id}/events`、`devices` 配下の全エンドポイント
（一覧・登録・コマンド発行/履歴）が管理者ログインを必須とする。`GET /parking-lots`（一覧・詳細）と
`GET /health` は Web（公開ビューア）が使うため認証不要のまま。デバイス ↔ API は従来どおり
`X-API-Key` による別系統の認証。

### 管理者アカウントの作成

セルフサインアップの画面は意図的に用意していない（Admin自体は登録済みユーザーだけが
使えるべきため）。初回のアカウントはCLIから作成する:

```bash
# ローカル venv から
cd services/api
PYTHONPATH=. .venv/bin/python scripts/create_admin_user.py <username>

# 起動中の docker compose に対して
docker compose exec api python scripts/create_admin_user.py <username>
```

パスワードは対話プロンプト（`getpass`）で入力する。同じユーザー名で再実行するとパスワードを
更新できる。

### 本番運用時の注意

- `.env` の `JWT_SECRET` は必ず固有のランダムな値に変更する（`openssl rand -hex 32`）。
  漏洩すると誰でも有効なアクセストークンを偽造できる。
- `admin-web` をHTTPS配下で公開する場合は `COOKIE_SECURE=true` にする（HTTP環境ではCookieが
  送信されなくなるため、ローカル開発時は `false` のままにする）。
- `admin-web` と `api` が異なるドメイン（=別サイト）で運用される場合、RTクッキーの
  `SameSite=Lax` では別サイト間のfetchに送られない。その場合は `SameSite=None; Secure`
  への変更が必要（`services/api/app/auth.py` の `set_refresh_cookie`）。
- リフレッシュトークンのローテーションは「使ったら失効」のみを実装しており、盗まれた
  トークンが正規ユーザーより先に使われた場合の再利用検知（トークンファミリー失効）は
  実装していない。

## API 仕様書（Swagger / OpenAPI）

OpenAPI仕様はコードのアノテーションから生成する。手書きのYAML/JSONは存在しない:

- 各エンドポイント（`routers/*.py`）の `summary=` 引数と関数のdocstringが、それぞれ
  OpenAPIの `summary` / `description` になる。
- 各Pydanticスキーマ（`schemas/*.py`）のフィールドに付けた `Field(description=...)` が、
  リクエスト/レスポンスの各項目の説明になる。
- `main.py` の `openapi_tags` がタグ（エンドポイントのグループ）の説明になる。

FastAPIがこれらのアノテーションを実行時に集めて `/docs`（Swagger UI）・`/redoc`・
`/openapi.json` を自動生成する。`api` リポジトリにはそれをコンパイルした静的スナップショットも
`services/api/docs/openapi.json` として置いてあり、ルーター・スキーマを変更したら以下で再生成する:

```bash
cd services/api
PYTHONPATH=. .venv/bin/python scripts/export_openapi.py
```

（中身は `app.openapi()` の呼び出し1つ — アノテーション付きのコードから実際に組み立てられた
スキーマをそのままファイルに書き出しているだけで、別途メンテナンスする仕様書ではない。）

## バックエンド開発

```bash
cd services/api
python3.12 -m venv .venv && .venv/bin/pip install -r requirements.txt

# テスト（SQLite のインメモリ DB を使用、MySQL 不要）
.venv/bin/python -m pytest

# マイグレーション追加（開発中に MySQL を起動した状態で）
.venv/bin/alembic revision --autogenerate -m "add xxx"
.venv/bin/alembic upgrade head
```

## フロントエンド開発

```bash
cd services/web    # または services/admin-web
npm install
npm run dev      # web: http://localhost:5173 / admin-web: http://localhost:5174（vite.config.tsのデフォルト5173との混同に注意し--portを指定）
npm run build    # 型チェック + 本番ビルド
```

`web` と `admin-web` は別々の Vite プロジェクトで、`src/api` 配下のAPIクライアントなどの
コードは意図的に重複させている（2画面だけの規模でモノレポの共有パッケージ化をするほどでは
ないため）。API のレスポンス型を変更した場合は両方に反映すること。

## データモデル

| テーブル | 役割 |
|---|---|
| `parking_lots` | 駐車場。`current_count` は入出庫イベントごとに増減する現在の駐車台数 |
| `devices` | エッジデバイス。API キーのハッシュ、最終通信時刻、最終ステータスを保持 |
| `parking_events` | 個々の入出庫イベント（`entry` / `exit`） |
| `device_commands` | デバイスへのコマンドキュー（`pending` → `delivered` → `completed`/`failed`） |

ER図・カラム定義・状態遷移などの詳細は `api` リポジトリの
[`docs/db-schema.md`](services/api/docs/db-schema.md) を参照。
