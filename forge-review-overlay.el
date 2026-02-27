;;; forge-review-overlay.el --- Show review status on forge PR list -*- lexical-binding:t -*-

;;; Commentary:

;; Display reviewDecision, CI status, and reviewer info as overlays
;; on the forge pull-request section, fetched via the gh CLI.
;;
;; Usage:
;;   M-x forge-review-overlay-mode     toggle (auto-refresh on magit refresh)
;;   M-x forge-review-overlay-show     show manually (cached)
;;   C-u M-x forge-review-overlay-show force re-fetch
;;   M-x forge-review-overlay-clear    remove overlays

;;; Code:

(require 'forge)

;;;; Options

(defcustom forge-review-overlay-ignored-reviewers '("github-actions" "claude")
  "List of reviewer logins to exclude from overlay display."
  :type '(repeat string)
  :group 'forge)

;;;; Cache

;; key: "owner/name"
;; value: (updated-timestamp . hash-table<number, alist>)
(defvar forge-review-overlay--cache (make-hash-table :test 'equal))

(defun forge-review-overlay--cache-valid-p (slug repo-updated)
  "Return non-nil if cache for SLUG was fetched at or after REPO-UPDATED."
  (when-let* ((entry (gethash slug forge-review-overlay--cache)))
    (not (string< (car entry) repo-updated))))

(defun forge-review-overlay--cache-get (slug)
  "Return cached data (hash-table) for SLUG."
  (cdr (gethash slug forge-review-overlay--cache)))

(defun forge-review-overlay--cache-set (slug data)
  "Update cache for SLUG with DATA (hash-table)."
  (puthash slug
           (cons (format-time-string "%Y-%m-%dT%H:%M:%SZ" nil t)
                 data)
           forge-review-overlay--cache))

;;;; Fetching data via gh

(defun forge-review-overlay--fetch (slug)
  "Fetch review info for SLUG via gh pr list.
Return a hash-table keyed by PR number."
  (unless (executable-find "gh")
    (user-error "Gh CLI is not installed"))
  (let* ((stderr-file (make-temp-file "forge-review-overlay-"))
         (json
          (unwind-protect
              (with-temp-buffer
                (unless (zerop
                         (call-process
                          "gh" nil (list t stderr-file) nil
                          "pr" "list"
                          "--repo" slug
                          "--state" "open"
                          "--limit" "100"
                          "--json" "number,reviewDecision,latestReviews,statusCheckRollup"))
                  (user-error "Gh pr list --repo %s failed: %s"
                              slug
                              (string-trim
                               (with-temp-buffer
                                 (insert-file-contents stderr-file)
                                 (buffer-string)))))
                (goto-char (point-min))
                (json-parse-buffer :array-type 'list
                                   :object-type 'alist))
            (delete-file stderr-file)))
         (table (make-hash-table :test 'eql)))
    (dolist (pr json)
      (puthash (alist-get 'number pr) pr table))
    table))

(defun forge-review-overlay--get-data (slug repo-updated &optional force)
  "Return data for SLUG at REPO-UPDATED, fetching via gh if needed.
When FORCE is non-nil, bypass cache."
  (if (and (not force)
           (forge-review-overlay--cache-valid-p slug repo-updated))
      (forge-review-overlay--cache-get slug)
    (let ((data (forge-review-overlay--fetch slug)))
      (forge-review-overlay--cache-set slug data)
      data)))

;;;; Formatting

(defun forge-review-overlay--format-decision (decision)
  "Format DECISION as an icon string, or nil if empty."
  (pcase decision
    ("APPROVED"          "✅")
    ("CHANGES_REQUESTED" "❌")
    ("REVIEW_REQUIRED"   "👀")
    (_ nil)))

(defun forge-review-overlay--format-ci (rollup)
  "Format ROLLUP as CI:pass/fail/pending, or nil if empty."
  (when (and rollup (sequencep rollup) (> (length rollup) 0))
    (let ((pass 0) (fail 0) (pending 0))
      (seq-doseq (check rollup)
        (pcase (or (alist-get 'conclusion check) "")
          ((or "SUCCESS" "NEUTRAL" "SKIPPED") (cl-incf pass))
          ((or "FAILURE" "CANCELLED" "TIMED_OUT") (cl-incf fail))
          (_ (cl-incf pending))))
      (propertize (format "CI:%d/%d/%d" pass fail pending)
                  'face (cond
                         ((> fail 0) 'error)
                         ((> pending 0) 'warning)
                         (t 'success))))))

(defun forge-review-overlay--format-review-state (state)
  "Format review STATE as an icon string."
  (pcase state
    ("APPROVED"          "✅")
    ("CHANGES_REQUESTED" "❌")
    ("COMMENTED"         "💬")
    ("DISMISSED"         "🚫")
    ("PENDING"           "⏳")
    (_                   "?")))

(defun forge-review-overlay--format-reviewers (reviews)
  "Format REVIEWS as reviewer list, or nil if empty."
  (when (and reviews (sequencep reviews) (> (length reviews) 0))
    (let ((parts nil))
      (seq-doseq (r reviews)
        (let* ((login (alist-get 'login (alist-get 'author r)))
               (state (or (alist-get 'state r) ""))
               (icon (forge-review-overlay--format-review-state state)))
          (unless (member login forge-review-overlay-ignored-reviewers)
            (push (format "%s:%s" login icon) parts))))
      (string-join (nreverse parts) " "))))

(defun forge-review-overlay--format-status (pr-data)
  "Format review status from PR-DATA as icon(reviewers), or nil if no data."
  (let ((decision (forge-review-overlay--format-decision
                   (alist-get 'reviewDecision pr-data)))
        (reviewers (forge-review-overlay--format-reviewers
                    (alist-get 'latestReviews pr-data))))
    (cond
     ((and decision reviewers) (format "%s(%s)" decision reviewers))
     (decision                 decision)
     (reviewers                reviewers)
     (t                        nil))))

(defun forge-review-overlay--format (pr-data)
  "Build overlay string from PR-DATA (alist)."
  (let ((parts (delq nil
                     (list
                      (forge-review-overlay--format-status pr-data)
                      (forge-review-overlay--format-ci
                       (alist-get 'statusCheckRollup pr-data))))))
    (when parts
      (concat " " (string-join parts " ")))))

;;;; Overlay operations

(defun forge-review-overlay-clear ()
  "Remove all review overlays from current buffer."
  (interactive)
  (remove-overlays (point-min) (point-max) 'forge-review-overlay t))

(defun forge-review-overlay--apply (data)
  "Apply review overlays from DATA (hash-table<number, alist>)."
  (forge-review-overlay-clear)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (when-let* ((section (magit-current-section))
                  (value (oref section value))
                  ((forge-pullreq-p value))
                  (number (oref value number))
                  (pr-data (gethash number data))
                  (text (forge-review-overlay--format pr-data)))
        (end-of-line)
        (let ((ov (make-overlay (point) (point))))
          (overlay-put ov 'forge-review-overlay t)
          (overlay-put ov 'after-string text)))
      (forward-line 1))))

;;;; Entry points

;;;###autoload
(defun forge-review-overlay-show (&optional force)
  "Show review status overlays on forge PR sections.
With prefix arg FORCE, re-fetch from gh."
  (interactive "P")
  (unless (derived-mode-p 'magit-mode)
    (user-error "Not in a magit buffer"))
  (if (called-interactively-p 'any)
      (forge-review-overlay--show-1 force)
    (condition-case err
        (forge-review-overlay--show-1 force)
      (user-error (message "forge-review-overlay: %s" (cadr err))))))

(defun forge-review-overlay--show-1 (force)
  "Internal: fetch and apply review overlays.
When FORCE is non-nil, bypass cache."
  (let* ((repo (or (forge-get-repository :tracked?)
                   (user-error "No tracked forge repository")))
         (slug (format "%s/%s" (oref repo owner) (oref repo name)))
         (repo-updated (oref repo updated))
         (data (forge-review-overlay--get-data slug repo-updated force)))
    (forge-review-overlay--apply data)))

;;;###autoload
(define-minor-mode forge-review-overlay-mode
  "Toggle review status overlays on forge PR sections.
When enabled, overlays are refreshed via
`magit-refresh-buffer-hook'."
  :lighter " FRO"
  (if forge-review-overlay-mode
      (progn
        (add-hook 'magit-refresh-buffer-hook #'forge-review-overlay-show nil t)
        (forge-review-overlay-show))
    (remove-hook 'magit-refresh-buffer-hook #'forge-review-overlay-show t)
    (forge-review-overlay-clear)))

(provide 'forge-review-overlay)
;;; forge-review-overlay.el ends here
