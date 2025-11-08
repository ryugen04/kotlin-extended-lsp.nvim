.PHONY: test lint format clean help

# デフォルトターゲット
.DEFAULT_GOAL := help

## help: ヘルプメッセージを表示
help:
	@echo "利用可能なターゲット:"
	@echo "  test       - すべてのテストを実行"
	@echo "  lint       - luacheckでコードをリント"
	@echo "  format     - styluaでコードをフォーマット"
	@echo "  clean      - 一時ファイルを削除"
	@echo "  ci         - CI環境でのすべてのチェックを実行"

## test: すべてのテストを実行
test:
	@echo "テストを実行中..."
	@for test_file in tests/*_spec.lua; do \
		echo "Running $$test_file..."; \
		nvim --headless --noplugin -u tests/minimal_init.lua \
			-c "lua require('plenary.test_harness').test_directory('$$test_file', { minimal_init = 'tests/minimal_init.lua' })" || exit 1; \
	done
	@echo "すべてのテストが成功しました!"

## lint: luacheckでコードをリント
lint:
	@echo "コードをリント中..."
	@if command -v luacheck >/dev/null 2>&1; then \
		luacheck lua/ plugin/ tests/; \
	else \
		echo "エラー: luacheckがインストールされていません"; \
		echo "インストール: luarocks install luacheck"; \
		exit 1; \
	fi

## format: styluaでコードをフォーマット
format:
	@echo "コードをフォーマット中..."
	@if command -v stylua >/dev/null 2>&1; then \
		stylua lua/ plugin/ tests/; \
	else \
		echo "エラー: styluaがインストールされていません"; \
		echo "インストール: cargo install stylua"; \
		exit 1; \
	fi

## format-check: フォーマットチェック（変更なし）
format-check:
	@echo "フォーマットをチェック中..."
	@if command -v stylua >/dev/null 2>&1; then \
		stylua --check lua/ plugin/ tests/; \
	else \
		echo "エラー: styluaがインストールされていません"; \
		exit 1; \
	fi

## clean: 一時ファイルを削除
clean:
	@echo "一時ファイルを削除中..."
	find . -type f -name '*.tmp' -delete
	find . -type f -name '*.log' -delete
	find . -type d -name '.luacov' -exec rm -rf {} + 2>/dev/null || true

## ci: CI環境でのすべてのチェック
ci: lint format-check test
	@echo "すべてのCIチェックが完了しました"

## coverage: テストカバレッジを測定（luacov使用）
coverage:
	@echo "テストカバレッジを測定中..."
	@if command -v luacov >/dev/null 2>&1; then \
		nvim --headless --noplugin -u tests/minimal_init.lua \
			-c "lua require('luacov')" \
			-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"; \
		luacov; \
		cat luacov.report.out | head -n 50; \
	else \
		echo "エラー: luacovがインストールされていません"; \
		echo "インストール: luarocks install luacov"; \
		exit 1; \
	fi
