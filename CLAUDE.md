# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

分割キーボード **LisM** の ZMK ファームウェア設定リポジトリ。
- ボード: `seeeduino_xiao_ble`
- シールド: `lism_left`, `lism_right`
- ZMK バージョン: `v0.3.0` で固定（`config/west.yml`）
- README は日本語。利用者向けのセットアップ・ビルド手順は `README.md` を参照。

## 実行環境

すべてのビルドコマンドは **devcontainer 内** で実行する前提（`.devcontainer/Dockerfile`、ベースイメージ `zmkfirmware/zmk-build-arm:stable` に `yq` を追加）。コンテナ起動時に `postCreateCommand` で `setup-west.sh` と `setup-claude.sh` が自動実行される。

`west` または `yq` が見つからない場合は、コンテナ外で実行している可能性が高い。

`_west/` および `firmware_builds/` は `.gitignore` 済み。**コミットしないこと。**

## よく使うコマンド

```bash
make                # = make all_p — studio を除く全ファームを並列ビルド
make all_studio_p   # ZMK Studio 版も含めて全ビルド（並列）
make all            # 逐次ビルド（studio 除外）
make all_studio     # 逐次ビルド（studio 含む）
make single         # build.yaml のエントリから対話的に1つ選択してビルド
make draw           # キーマップ可視化のみ実行 (keymap-drawer/*.svg を再生成)
make clean          # firmware_builds/ を削除
make setup-west     # _west ワークスペースを初期化＋ west update
PARALLEL=4 make all_p   # 並列ジョブ数を上書き（既定は CPU コア数）
```

成果物は `firmware_builds/` に `<artifact-name>.uf2`（uf2 が無ければ `.bin`）として出力される。

## アーキテクチャ

### West ワークスペースは `_west/` に隔離

`west init -l` は manifest の **親ディレクトリ** をワークスペースとして初期化する。リポジトリ直下を汚さないため、`setup-west.sh` は次の手順を取る:

1. `_west/config/west.yml` を `config/west.yml` へのシンボリックリンクとして作成
2. `_west/` 内で `west init -l ./config` を実行

セットアップ後、`_west/` 配下に `.west/`, `zephyr/`, `modules/`, `zmk/` などが配置される。`west build` は必ず `_west/` に `cd` してから `-s zmk/app` で実行している。

リポジトリ直下に `.west/` が誤生成された場合、`setup-west.sh` が次回実行時に削除する。**コミットしないこと。**

### `build.yaml` がビルド定義の唯一の正本

GitHub Actions ワークフロー（`zmkfirmware/zmk/.github/workflows/build-user-config.yml@v0.3.0` を再利用）と、ローカルの `scripts/build-matrix.sh` の **両方が同じ `build.yaml`** を参照する。各エントリは `board`, `shield`, `snippet`（任意）, `cmake-args`（任意）, `artifact-name` を持つ。ファームウェアの追加・変更は `build.yaml` を編集する。**ローカル専用のビルド設定ファイルは存在しない。**

`build-matrix.sh` のフィルタは環境変数 `FILTER_MODE` で切り替わる:
- `all` — 全エントリ
- `exclude_studio` — `artifact-name` に `studio` を含まないエントリのみ（`make all` / `make all_p` が使用）
- `include_studio` — `studio` を含むエントリのみ

判定は **`artifact-name` の単純な文字列マッチ**。新規エントリの命名は studio 対応の有無を反映させること。

### セントラル／ペリフェラル と 機能フラグ

役割・機能の切り替えは別キーマップではなく、`build.yaml` の cmake 引数とスニペットで行う:

- `-DCONFIG_ZMK_SPLIT_ROLE_CENTRAL=y` — セントラル側（ホストと通信する側）
- `-DCONFIG_ZMK_STUDIO=y` — ZMK Studio を有効化
- トラックボール／非トラックボールは **snippet** で選択（`trackball-central` / `non-trackball-central` / `trackball-peripheral` / `non-trackball-peripheral`）。実体は `snippets/` 配下。

既定構成は **右=Central, 左=Peripheral**。入れ替えるには README 記載の通り `build.yaml` の "Central = Right" ブロックをコメントアウトし、"Central = Left" ブロックをコメント解除する（両方のブロックが既に用意されている）。

### `west build` 呼び出しの形

`scripts/build-matrix.sh` と `scripts/build-single.sh` はおおむね次のコマンドを組み立てる:

```
west build -s zmk/app -d <tmpdir> -b <board> [-S <snippet>] -- \
    -DZMK_CONFIG=<repo>/config \
    -DZMK_EXTRA_MODULES=<repo> \
    [-D SHIELD="<重複除去・空白区切りのシールド>"] \
    [<build.yaml の cmake-args>]
```

- `ZMK_EXTRA_MODULES=<repo>` により `boards/shields/lism/` が認識される。
- shield は GitHub Actions マトリクス互換のため空白区切りで指定（例: `lism_left rgbled_adapter`）。スクリプト側で重複を除去している。
- 成果物コピーは `scripts/lib/build-helpers.sh::copy_artifacts`（uf2 を優先、無ければ bin）。

### キーマップと可視化

- `config/lism.keymap` がキーマップ本体。`config/lism.json` は keymap-drawer 用のレイアウト定義。
- `keymap-drawer/lism.svg` および `lism.yaml` は **自動生成物**。手で編集しないこと。
- 生成経路は 2 系統:
  - **GitHub Actions**: `.github/workflows/drawer-keymap.yml`（caksoylar/keymap-drawer）が `config/*` 変更時に自動生成・自動コミット（コミットメッセージは `[Draw] ...`）。
  - **ローカル**: `scripts/draw-keymap.sh` が `make` の全ビルドターゲット（`all*` / `single`）の末尾、または `make draw` で実行される。`config/*.keymap` を走査し、対応する `config/*.json` があれば `-j` で渡して draw する。
- ローカル draw は `keymap-drawer` Python パッケージに依存。Dockerfile で同梱済みだが、未インストール環境でも `scripts/draw-keymap.sh` 内の自動 install フォールバックが効く（初回のみ apt + pip で 20 秒程度、以降は < 1 秒）。
- 同じ `keymap-drawer/config.yaml` を CI とローカルが共有しているため、生成結果は一致する想定。

## CI

- `.github/workflows/build.yml` — `boards/**`, `config/**`, `snippets/**`, `build.yaml` の変更時に ZMK 公式の再利用ワークフローを呼び出す。
- `.github/workflows/release.yml` — `v*` タグ push で発火。同じ再利用ワークフローでビルド → アーティファクトを zip 化 → 自動生成チェンジログ付きで GitHub Release に添付。

## 個体構成

- 左側モジュール: 非トラックボール（キースイッチ／エンコーダー）
- 右側モジュール: トラックボール
- セントラル／ペリフェラル: 既定の「右=Central, 左=Peripheral」のまま
- 必要なファーム（`build.yaml` の `artifact-name` 由来）:
  - `lism_left_peripheral_non_trackball.uf2`
  - `lism_right_central_trackball.uf2`

## ブランチ戦略

- `main` — upstream（`4mplelab/zmk-config-LisM`）追従専用。**個人の変更を直接入れない。**
- `custom-main`（デフォルトブランチ）— 個人カスタマイズの長期ブランチ。
- 本家更新の取り込み手順:

```bash
git checkout main
git pull upstream main
git push origin main
git checkout custom-main
git merge main
git push
```

## 書き込み手順

- ブートローダー起動: 底面リセットボタンを素早く 2 回押す
  - 代替: 反対側の外側 1 番下キーを押しながら対象側の外側 1 番下キーを押す／XIAO のリセットボタンを 2 回押す
- USB ドライブとして認識されたら `.uf2` をドラッグ＆ドロップ
- 書き込み順序: **右（セントラル）→ 左（ペリフェラル）**
- 左右ペアリングが切れた場合は `settings_reset-*.uf2` を両側に書き込んでから正規ファームを書き直す

## 参考リンク

- LisM 公式ドキュメント: https://4mplelab.github.io/LisM/
- ZMK 公式: https://zmk.dev/docs/
- keymap-editor: https://nickcoutsos.github.io/keymap-editor/
