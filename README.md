# forge-review-overlay

Emacs package that displays review status (reviewDecision, CI status, reviewer info) as overlays on the forge pull-request section, fetched via the `gh` CLI.

## Features

- **Review Decision**: Shows APPROVED / CHANGES_REQUESTED / REVIEW_REQUIRED with color-coded faces
- **CI Status**: Displays pass/fail/pending counts from status check rollup
- **Reviewer Info**: Lists individual reviewer states (approved, changes requested, commented)
- **Caching**: Fetched data is cached and reused until the repository is updated
- **Auto-refresh**: Integrates with `magit-refresh-buffer-hook` for seamless updates

## Requirements

- Emacs 28.1 or later
- [forge](https://github.com/magit/forge)
- [gh](https://cli.github.com/) CLI

## Installation

### Manual Installation

1. Clone this repository or download `forge-review-overlay.el`
2. Add to your Emacs configuration:

```elisp
(add-to-list 'load-path "/path/to/forge-review-overlay")
(require 'forge-review-overlay)
```

### Using straight.el

```elisp
(straight-use-package
 '(forge-review-overlay :type git :host github :repo "ofnhwx/forge-review-overlay"))
```

## Usage

### Enable automatically via hook

```elisp
(add-hook 'magit-status-mode-hook #'forge-review-overlay-mode)
```

### Manual commands

```elisp
;; Toggle auto-refresh on magit refresh
M-x forge-review-overlay-mode

;; Show manually (uses cache)
M-x forge-review-overlay-show

;; Force re-fetch
C-u M-x forge-review-overlay-show

;; Remove overlays
M-x forge-review-overlay-clear
```

## Configuration

### Ignored reviewers

```elisp
(setq forge-review-overlay-ignored-reviewers '("github-actions" "claude"))
```

## License

GPL-3.0-or-later

## Author

ofnhwx
