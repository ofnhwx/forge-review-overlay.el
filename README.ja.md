# forge-review-overlay

forge の PR セクションに、レビュー状況（reviewDecision、CI ステータス、レビュアー情報）をオーバーレイ表示する Emacs パッケージ。`gh` CLI 経由でデータを取得します。

## 機能

- **レビュー判定**: APPROVED / CHANGES_REQUESTED / REVIEW_REQUIRED を色分けして表示
- **CI ステータス**: ステータスチェックの pass/fail/pending 件数を表示
- **レビュアー情報**: 各レビュアーの状態（承認、変更要求、コメント）を一覧表示
- **キャッシュ**: 取得したデータはリポジトリの更新時刻までキャッシュされます
- **自動更新**: `magit-refresh-buffer-hook` と連携して自動的にオーバーレイを更新

## 必要環境

- Emacs 28.1 以降
- [forge](https://github.com/magit/forge)
- [gh](https://cli.github.com/) CLI

## インストール

### 手動インストール

1. このリポジトリをクローンまたは `forge-review-overlay.el` をダウンロード
2. Emacs 設定に以下を追加：

```elisp
(add-to-list 'load-path "/path/to/forge-review-overlay")
(require 'forge-review-overlay)
```

### straight.el を使用

```elisp
(straight-use-package
 '(forge-review-overlay :type git :host github :repo "ofnhwx/forge-review-overlay"))
```

## 使い方

### hook で自動有効化

```elisp
(add-hook 'magit-status-mode-hook #'forge-review-overlay-mode)
```

### 手動コマンド

```elisp
;; magit 更新時に自動でオーバーレイを更新
M-x forge-review-overlay-mode

;; 手動で表示（キャッシュを使用）
M-x forge-review-overlay-show

;; 強制的に再取得
C-u M-x forge-review-overlay-show

;; オーバーレイを削除
M-x forge-review-overlay-clear
```

## カスタマイズ

### 除外するレビュアー

```elisp
(setq forge-review-overlay-ignored-reviewers '("github-actions" "claude"))
```

## ライセンス

GPL-3.0-or-later

## 作者

ofnhwx
