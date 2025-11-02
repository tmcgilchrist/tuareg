;;; opam-ts-mode.el --- tree-sitter support for OPAM files  -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Free Software Foundation, Inc.

;; Author     : Tim McGilchrist <timmcgil@gmail.com>
;; Maintainer : Tim McGilchrist <timmcgil@gmail.com>
;; Package-Requires: ((emacs "29.1") tuareg)
;; Created    : November 2024
;; Keywords   : opam ocaml languages tree-sitter

;;; Commentary:
;;
;; Tree-sitter support for OPAM package files.
;; Provides tree-sitter based syntax highlighting and indentation.

;;; Code:

(require 'treesit)
(require 'tuareg)

(declare-function treesit-parser-create "treesit.c")
(declare-function treesit-node-type "treesit.c")

(defvar opam-ts-mode--syntax-table
  (let ((st (make-syntax-table)))
    ;; OPAM comments start with # and go to end of line
    (modify-syntax-entry ?# "<" st)
    (modify-syntax-entry ?\n ">" st)
    ;; Also support OCaml-style block comments (* *)
    (modify-syntax-entry ?\( "()1n" st)
    (modify-syntax-entry ?\) ")(4n" st)
    (modify-syntax-entry ?* ". 23" st)
    ;; Strings
    (modify-syntax-entry ?\" "\"" st)
    st)
  "Syntax table for `opam-ts-mode'.")

(defvar opam-ts-mode--keywords
  '("opam-version" "name" "version" "synopsis" "description"
    "maintainer" "authors" "license" "tags" "homepage" "doc"
    "bug-reports" "dev-repo" "depends" "depopts" "conflicts"
    "conflict-class" "available" "flags" "setenv" "build" "install"
    "remove" "run-test" "test" "depexts" "messages" "post-messages"
    "substs" "patches" "build-env" "features" "x-env" "url" "src"
    "checksum" "mirrors" "pin-depends")
  "OPAM keywords for tree-sitter font-locking.")

(defun opam-ts-mode--font-lock-settings (language)
  "Tree-sitter font-lock settings for LANGUAGE (opam)."
  (treesit-font-lock-rules
   :language language
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language language
   :feature 'keyword
   '((variable name: (ident) @font-lock-keyword-face)
     (section kind: (ident) @font-lock-keyword-face))

   :language language
   :feature 'string
   '((string) @font-lock-string-face
     (escape_sequence) @font-lock-escape-face)

   :language language
   :feature 'number
   '((int) @font-lock-number-face)

   :language language
   :feature 'boolean
   '((bool) @font-lock-constant-face)

   :language language
   :feature 'operator
   '((relop) @font-lock-operator-face
     (pfxop) @font-lock-operator-face
     (envop) @font-lock-operator-face
     "&" @font-lock-operator-face
     "|" @font-lock-operator-face)

   :language language
   :feature 'delimiter
   '(([":" "{" "}" "[" "]" "(" ")"]) @font-lock-delimiter-face)

   :language language
   :feature 'variable
   '((ident) @font-lock-variable-use-face)

   :language language
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face)))

(defcustom opam-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `opam-ts-mode'."
  :type 'integer
  :group 'tuareg
  :safe 'integerp)

(defvar opam-ts-mode--indent-rules
  `((opam
     ((node-is "}") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((parent-is "source_file") column-0 0)
     ((parent-is "variable") parent-bol opam-ts-mode-indent-offset)
     ((parent-is "section") parent-bol opam-ts-mode-indent-offset)
     ((parent-is "list") parent-bol opam-ts-mode-indent-offset)
     ((parent-is "group") parent-bol opam-ts-mode-indent-offset)
     ;; Default fallback
     (catch-all parent-bol 0)))
  "Tree-sitter indent rules for `opam-ts-mode'.")

;;;###autoload
(define-derived-mode opam-ts-mode prog-mode "OPAM"
  "Major mode for editing OPAM package files, powered by tree-sitter."
  :group 'tuareg
  :syntax-table opam-ts-mode--syntax-table

  (unless (treesit-ready-p 'opam)
    (if (and (require 'tuareg-treesitter-install nil t)
             (yes-or-no-p "Tree-sitter grammar for OPAM is not installed. Install it now? "))
        (progn
          (tuareg-treesitter--install-grammars-noninteractive)
          (unless (treesit-ready-p 'opam)
            (error "Failed to install tree-sitter grammar for OPAM")))
      (error "Tree-sitter for OPAM isn't available. Run M-x tuareg-treesitter-install-grammars")))

  (treesit-parser-create 'opam)

  ;; Comments
  (setq-local comment-start "#")
  (setq-local comment-end "")
  (setq-local comment-start-skip "#+ *")

  ;; Indentation
  (setq-local treesit-simple-indent-rules opam-ts-mode--indent-rules)

  ;; Font-lock
  (setq-local treesit-font-lock-settings
              (opam-ts-mode--font-lock-settings 'opam))
  (setq-local treesit-font-lock-feature-list
              '((comment)
                (keyword)
                (string number boolean)
                (operator delimiter variable error)))

  (setq-local treesit-language-at-point-function
              (lambda (_pos) 'opam))

  ;; Imenu
  (setq-local treesit-simple-imenu-settings
              '(("Variable" "\\`variable\\'" nil nil)
                ("Section" "\\`section\\'" nil nil)))

  (treesit-major-mode-setup))

(provide 'opam-ts-mode)

;;; opam-ts-mode.el ends here
