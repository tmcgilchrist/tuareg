;;; menhir-ts-mode.el --- tree-sitter support for Menhir  -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Free Software Foundation, Inc.

;; Author     : Tree-sitter integration for Tuareg
;; Maintainer : Tree-sitter integration for Tuareg
;; Package-Requires: ((emacs "29.1") tuareg)
;; Created    : November 2024
;; Keywords   : menhir ocamlyacc languages tree-sitter

;;; Commentary:
;;
;; Tree-sitter support for Menhir (and Ocamlyacc) source files.
;; Provides tree-sitter based syntax highlighting and indentation.

;;; Code:

(require 'treesit)
(require 'tuareg)

(declare-function treesit-parser-create "treesit.c")
(declare-function treesit-node-type "treesit.c")

(defvar menhir-ts-mode--syntax-table
  (let ((st (make-syntax-table tuareg-mode-syntax-table)))
    ;; Menhir comments are hellish: can be C, C++, or OCaml style!
    (modify-syntax-entry ?/ ". 124b" st)
    (modify-syntax-entry ?\n "> b" st)
    st)
  "Syntax table for `menhir-ts-mode'.")

(defvar menhir-ts-mode--keywords
  '("%{" "%}" "%token" "%type" "%start" "%left" "%right" "%nonassoc"
    "%parameter" "%attribute" "%on_error_reduce" "%public" "%inline" "%prec"
    "let")
  "Menhir keywords for tree-sitter font-locking.")

(defun menhir-ts-mode--font-lock-settings (language)
  "Tree-sitter font-lock settings for LANGUAGE (menhir)."
  (treesit-font-lock-rules
   :language language
   :feature 'comment
   '((line_comment) @font-lock-comment-face
     (comment) @font-lock-comment-face
     (ocaml_comment) @font-lock-comment-face)

   :language language
   :feature 'keyword
   `([,@menhir-ts-mode--keywords] @font-lock-keyword-face)

   :language language
   :feature 'type
   '((uid) @font-lock-type-face
     (symbol (uid) @font-lock-type-face))

   :language language
   :feature 'function
   '((rule_name) @font-lock-function-name-face
     (symbol (lid) @font-lock-function-name-face))

   :language language
   :feature 'variable
   '((lid) @font-lock-variable-use-face)

   :language language
   :feature 'string
   '((qid) @font-lock-string-face)

   :language language
   :feature 'operator
   '((modifier) @font-lock-operator-face)

   :language language
   :feature 'delimiter
   '(([":" ";" "|" "," "(" ")" "[" "]" "{" "}"]) @font-lock-delimiter-face)

   :language language
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face)))

(defcustom menhir-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `menhir-ts-mode'."
  :type 'integer
  :group 'tuareg-menhir
  :safe 'integerp)

(defvar menhir-ts-mode--indent-rules
  `((menhir
     ((node-is "%%") column-0 0)
     ((parent-is "source_file") column-0 0)
     ((node-is "rule") column-0 0)
     ((node-is "production") parent-bol menhir-ts-mode-indent-offset)
     ((parent-is "production") parent-bol menhir-ts-mode-indent-offset)
     ((node-is "|") parent-bol menhir-ts-mode-indent-offset)
     ((parent-is "rule") parent-bol menhir-ts-mode-indent-offset)
     ;; Default fallback
     (catch-all parent-bol 0)))
  "Tree-sitter indent rules for `menhir-ts-mode'.")

;;;###autoload
(define-derived-mode menhir-ts-mode prog-mode "Menhir"
  "Major mode for editing Menhir (and Ocamlyacc) files, powered by tree-sitter."
  :group 'tuareg-menhir
  :syntax-table menhir-ts-mode--syntax-table

  (unless (treesit-ready-p 'menhir)
    (if (and (require 'tuareg-treesitter-install nil t)
             (yes-or-no-p "Tree-sitter grammar for Menhir is not installed. Install it now? "))
        (progn
          (tuareg-treesitter--install-grammars-noninteractive)
          (unless (treesit-ready-p 'menhir)
            (error "Failed to install tree-sitter grammar for Menhir")))
      (error "Tree-sitter for Menhir isn't available. Run M-x tuareg-treesitter-install-grammars")))

  (treesit-parser-create 'menhir)

  ;; Comments
  (setq-local comment-start "/* ")
  (setq-local comment-end " */")
  (setq-local comment-start-skip "\\(?:[(/]\\*+\\|//+\\)[ \t]*")
  (setq-local comment-end-skip "[ \t]*\\(?:\\*+[/)]\\)?")

  ;; Indentation
  (setq-local treesit-simple-indent-rules menhir-ts-mode--indent-rules)

  ;; Font-lock
  (setq-local treesit-font-lock-settings
              (menhir-ts-mode--font-lock-settings 'menhir))
  (setq-local treesit-font-lock-feature-list
              '((comment)
                (keyword)
                (type function variable string)
                (operator delimiter error)))

  (setq-local treesit-language-at-point-function
              (lambda (_pos) 'menhir))

  ;; Imenu
  (setq-local treesit-simple-imenu-settings
              '(("Rule" "\\`rule_name\\'" nil nil)))

  (treesit-major-mode-setup))

(provide 'menhir-ts-mode)

;;; menhir-ts-mode.el ends here
