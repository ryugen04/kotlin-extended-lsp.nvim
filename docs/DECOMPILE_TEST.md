# デコンパイル機能のテスト手順

このドキュメントは、JAR/classデコンパイル機能の手動テスト手順を示します。

## 前提条件

1. kotlin-lspがインストールされている
2. test-projectの依存関係がダウンロードされている
3. プラグインが正しくロードされている

## テストケース

### ケース1: `:KotlinDecompile` コマンドのテスト

1. Neovimでtest-projectのKotlinファイルを開く:
   ```bash
   cd /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim
   nvim test-project/src/main/kotlin/com/example/TestDecompile.kt
   ```

2. kotlin-lspが起動するまで待つ（ステータスバーで確認）

3. カーソルを `Application` の上に置く（17行目）:
   ```kotlin
   fun Application.testModule() {
       ^^^^^^^^^^ <- ここにカーソル
   ```

4. `:KotlinDecompile` を実行

5. **期待される結果**:
   - `textDocument/definition` が実行される
   - ApplicationクラスがJAR内にあることを検出
   - `workspace/executeCommand: decompile` が実行される
   - 新しいウィンドウにデコンパイル結果が表示される
   - バッファ名: `jar://io/ktor/server/application/Application.kt`
   - バッファは読み取り専用

6. **確認項目**:
   - [ ] デコンパイルが成功したか
   - [ ] Kotlinコードが正しく表示されているか
   - [ ] シンタックスハイライトが適用されているか
   - [ ] バッファが読み取り専用か

### ケース2: `gd` キーマップのテスト（自動デコンパイル）

1. 同じファイルで、カーソルを `Table` の上に置く（28行目）:
   ```kotlin
   object Users : Table() {
                  ^^^^^ <- ここにカーソル
   ```

2. `gd` を押す

3. **期待される結果**:
   - 自動的にデコンパイルが実行される
   - Exposedの `Table` クラスが表示される

### ケース3: `<leader>kd` キーマップのテスト

1. カーソルを `startKoin` の上に置く（38行目）:
   ```kotlin
   startKoin {
   ^^^^^^^^^ <- ここにカーソル
   ```

2. `<leader>kd` を押す

3. **期待される結果**:
   - Koinの `startKoin` 関数が表示される

### ケース4: 通常のファイルでの `gd` テスト

1. カーソルを `appModule` の上に置く（35行目）:
   ```kotlin
   modules(appModule)
           ^^^^^^^^^ <- ここにカーソル
   ```

2. `gd` を押す

3. **期待される結果**:
   - 通常の定義ジャンプが実行される
   - 同じファイルの `appModule` 定義（34行目）へジャンプ
   - デコンパイルは実行されない

### ケース5: キャッシュのテスト

1. ケース1で開いた `Application` のバッファを閉じる

2. 再度 `Application` にカーソルを置いて `:KotlinDecompile`

3. **期待される結果**:
   - キャッシュから即座に表示される
   - LSPリクエストは送信されない（高速）

### ケース6: キャッシュクリアのテスト

1. `:KotlinDecompileClearCache` を実行

2. **期待される結果**:
   - "Decompilation cache cleared" と表示される
   - 開いていたデコンパイル結果のバッファが閉じられる

3. 再度 `:KotlinDecompile` を実行

4. **期待される結果**:
   - 再度LSPリクエストが送信される
   - デコンパイルが実行される

## エラーケース

### エラー1: kotlin-lspが起動していない

1. kotlin-lspを停止した状態で `:KotlinDecompile`

2. **期待される結果**:
   - エラーメッセージ: "kotlin-lsp client not found"

### エラー2: 定義が見つからない

1. 存在しないシンボルにカーソルを置いて `:KotlinDecompile`

2. **期待される結果**:
   - エラーメッセージ: "No definition found"

### エラー3: JAR内ではないファイル

1. プロジェクト内のシンボルにカーソルを置いて `:KotlinDecompile`

2. **期待される結果**:
   - 通常の `gd` と同じ動作（定義へジャンプ）

## パフォーマンステスト

### 大規模ファイルでのデコンパイル

1. 大きなライブラリクラスをデコンパイル（例: Ktor の `ApplicationCall`）

2. **確認項目**:
   - [ ] デコンパイルが完了するまでの時間（5秒以内が目標）
   - [ ] バッファの表示が遅延なく行われるか
   - [ ] スクロールが滑らかか

### 複数ファイルの同時デコンパイル

1. 複数の外部ライブラリクラスを次々にデコンパイル

2. **確認項目**:
   - [ ] キャッシュが正しく機能しているか
   - [ ] メモリ使用量が増大しないか
   - [ ] LSPサーバーが安定しているか

## 実装の検証項目

### コード品質

- [ ] utils.lua の関数が正しく動作するか
- [ ] decompile.lua のエラーハンドリングが適切か
- [ ] init.lua の統合が疎結合か

### ユーザビリティ

- [ ] コマンド名が直感的か
- [ ] エラーメッセージが分かりやすいか
- [ ] キーマップが使いやすいか

### 設定オプション

- [ ] `enable_decompile = false` で無効化できるか
- [ ] `override_gd = false` で `gd` をオーバーライドしないようにできるか
- [ ] `split_type` オプションが機能するか（vertical, horizontal, tab）

## 次のステップ

テスト完了後、以下を実施:

1. テスト結果をこのドキュメントに記録
2. 発見されたバグを修正
3. パフォーマンス問題があれば最適化
4. アプローチの最適性を検討
