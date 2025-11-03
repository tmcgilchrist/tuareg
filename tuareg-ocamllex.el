;;; tuareg-ocamllex.el --- Support for OCamllex source code  -*- lexical-binding: t; -*-

;; Copyright (C) 2025  Free Software Foundation, Inc

;; Author: Tim McGilchrist <timmcgil@gmail.com>
;; Keywords: ocamllex

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Major mode to edit OCamllex source files (.mll).
;;
;; Currently provides:
;; - Font-lock highlighting
;; - Automatic indentation
;; - Imenu
;; - Optional tree-sitter support

;;; Code:

(require 'cl-lib)
(require 'tuareg)

(defgroup tuareg-ocamllex ()
  "Major mode to edit OCamllex source files."
  :group 'tuareg)

(defvar tuareg-ocamllex-mode-syntax-table
  (let ((st (make-syntax-table tuareg-mode-syntax-table)))
    st))

(defconst tuareg-ocamllex--keywords
  '("and" "as" "parse" "refill" "rule" "shortest" "let"))

;;;; Indentation

(defcustom tuareg-ocamllex-basic-indent 2
  "Default basic indentation step for OCamllex files."
  :type 'integer
  :group 'tuareg-ocamllex)

(defcustom tuareg-ocamllex-rule-indent tuareg-ocamllex-basic-indent
  "Indentation column of rules."
  :type 'integer
  :group 'tuareg-ocamllex)

(defcustom tuareg-ocamllex-action-indent tuareg-ocamllex-basic-indent
  "Indentation action w.r.t rules."
  :type 'integer
  :group 'tuareg-ocamllex)

(defun tuareg-ocamllex--indent-column ()
  (save-excursion
    (beginning-of-line)
    (skip-chars-forward " \t")
    (cond
     ((looking-at "rule\\|and") 0)
     ((looking-at "|") tuareg-ocamllex-rule-indent)
     ((looking-at "{")
      (+ tuareg-ocamllex-rule-indent tuareg-ocamllex-action-indent))
     (t 0))))

(defun tuareg-ocamllex--indent (&optional _)
  (let ((col (tuareg-ocamllex--indent-column)))
    (if (save-excursion (skip-chars-backward " \t") (bolp))
        (indent-line-to col)
      (save-excursion (indent-line-to col)))))

;;;; Font-lock

(defvar tuareg-ocamllex-font-lock-keywords
  `((,(concat "\\<\\(?:" (regexp-opt tuareg-ocamllex--keywords) "\\)\\>")
     (0 font-lock-keyword-face))
    ("^\\([a-z_][a-zA-Z0-9_']*\\)\\s-*=" (1 font-lock-function-name-face))
    ("^rule\\s-+\\([a-z_][a-zA-Z0-9_']*\\)" (1 font-lock-function-name-face))))

;;;; Imenu

(defvar tuareg-ocamllex-imenu-generic-expression
  '((nil "^rule\\s-+\\([a-z_][a-zA-Z0-9_']*\\)" 1)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.mll\\'" . tuareg-ocamllex-mode))

;;;###autoload
(define-derived-mode tuareg-ocamllex-mode prog-mode "OCamllex"
  "Major mode to edit OCamllex files."
  ;; Check if tree-sitter mode should be used
  (if (and tuareg-mode-treesitter-derive
           (version<= "29.1" emacs-version)
           (require 'treesit nil t)
           (fboundp 'treesit-ready-p)
           (treesit-ready-p 'ocamllex))
      (progn
        ;; Use tree-sitter mode
        (require 'ocamllex-ts-mode)
        ;; Create tree-sitter parser
        (treesit-parser-create 'ocamllex)

        ;; Comments
        (setq-local comment-start "(* ")
        (setq-local comment-end " *)")
        (setq-local comment-start-skip "(\\*+[ \t]*")

        ;; Indentation
        (setq-local treesit-simple-indent-rules ocamllex-ts-mode--indent-rules)

        ;; Font-lock
        (setq-local treesit-font-lock-settings
                    (ocamllex-ts-mode--font-lock-settings 'ocamllex))
        (setq-local treesit-font-lock-feature-list
                    '((comment)
                      (keyword)
                      (function variable constant string)
                      (escape operator delimiter error)))

        (setq-local treesit-language-at-point-function
                    (lambda (_pos) 'ocamllex))

        ;; Imenu
        (setq-local treesit-simple-imenu-settings
                    '(("Entry" "\\`lexer_entry_name\\'" nil nil)))

        (treesit-major-mode-setup))

    ;; Use standard mode (no tree-sitter)
    (setq-local indent-line-function #'tuareg-ocamllex--indent)
    (setq-local comment-start "(* ")
    (setq-local comment-end " *)")
    (setq-local comment-start-skip "(\\*+[ \t]*")
    (setq-local font-lock-defaults '(tuareg-ocamllex-font-lock-keywords))
    (setq-local imenu-generic-expression tuareg-ocamllex-imenu-generic-expression))
  )

(provide 'tuareg-ocamllex)
;;; tuareg-ocamllex.el ends here
