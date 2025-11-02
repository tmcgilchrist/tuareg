;;; ocamllex-ts-mode.el --- tree-sitter support for OCamllex  -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Free Software Foundation, Inc.

;; Author     : Tim McGilchrist <timmcgil@gmail.com>
;; Maintainer : Tim McGilchrist <timmcgil@gmail.com>
;; Package-Requires: ((emacs "29.1") tuareg)
;; Created    : November 2024
;; Keywords   : ocamllex languages tree-sitter

;;; Commentary:
;;
;; Tree-sitter support for OCamllex source files.
;; Provides tree-sitter based syntax highlighting and indentation.

;;; Code:

(require 'treesit)
(require 'tuareg)

(declare-function treesit-parser-create "treesit.c")
(declare-function treesit-node-type "treesit.c")

(defvar ocamllex-ts-mode--syntax-table
  (let ((st (make-syntax-table tuareg-mode-syntax-table)))
    ;; OCamllex uses OCaml-style comments
    st)
  "Syntax table for `ocamllex-ts-mode'.")

(defvar ocamllex-ts-mode--keywords
  '("and" "as" "parse" "refill" "rule" "shortest" "let")
  "OCamllex keywords for tree-sitter font-locking.")

(defun ocamllex-ts-mode--font-lock-settings (language)
  "Tree-sitter font-lock settings for LANGUAGE (ocamllex)."
  (treesit-font-lock-rules
   :language language
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language language
   :feature 'keyword
   `([,@ocamllex-ts-mode--keywords] @font-lock-keyword-face)

   :language language
   :feature 'function
   '((lexer_entry_name) @font-lock-function-name-face)

   :language language
   :feature 'variable
   '((regexp_name) @font-lock-variable-name-face
     (lexer_argument) @font-lock-variable-use-face)

   :language language
   :feature 'constant
   '((any) @font-lock-constant-face
     (eof) @font-lock-constant-face)

   :language language
   :feature 'string
   '((string) @font-lock-string-face
     (character) @font-lock-string-face)

   :language language
   :feature 'escape
   :override t
   '((escape_sequence) @font-lock-escape-face)

   :language language
   :feature 'operator
   '((regexp_difference "#" @font-lock-operator-face)
     (regexp_repetition ["*" "+" "?"] @font-lock-operator-face)
     (regexp_alternative "|" @font-lock-operator-face))

   :language language
   :feature 'delimiter
   '((["[" "]" "(" ")" "{" "}" "=" "|" "-"] @font-lock-delimiter-face))

   :language language
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face)))

(defcustom ocamllex-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `ocamllex-ts-mode'."
  :type 'integer
  :group 'tuareg
  :safe 'integerp)

(defvar ocamllex-ts-mode--indent-rules
  `((ocamllex
     ((parent-is "lexer_definition") column-0 0)
     ((node-is "rule") column-0 0)
     ((node-is "lexer_entry") column-0 0)
     ((node-is "and") column-0 0)
     ((parent-is "lexer_entry") parent-bol ocamllex-ts-mode-indent-offset)
     ((node-is "|") parent-bol ocamllex-ts-mode-indent-offset)
     ((parent-is "action") parent-bol ocamllex-ts-mode-indent-offset)
     ;; Default fallback
     (catch-all parent-bol 0)))
  "Tree-sitter indent rules for `ocamllex-ts-mode'.")

;;;###autoload
(define-derived-mode ocamllex-ts-mode prog-mode "OCamllex"
  "Major mode for editing OCamllex files, powered by tree-sitter."
  :group 'tuareg
  :syntax-table ocamllex-ts-mode--syntax-table

  (unless (treesit-ready-p 'ocamllex)
    (if (and (require 'tuareg-treesitter-install nil t)
             (yes-or-no-p "Tree-sitter grammar for OCamllex is not installed. Install it now? "))
        (progn
          (tuareg-treesitter--install-grammars-noninteractive)
          (unless (treesit-ready-p 'ocamllex)
            (error "Failed to install tree-sitter grammar for OCamllex")))
      (error "Tree-sitter for OCamllex isn't available. Run M-x tuareg-treesitter-install-grammars")))

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

(provide 'ocamllex-ts-mode)

;;; ocamllex-ts-mode.el ends here
