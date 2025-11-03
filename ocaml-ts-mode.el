;;; ocaml-ts-mode.el --- tree-sitter support for Ocaml  -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Terrateam B.V.

;; Author     : Malcolm Matalka <malcolm@terrateam.io>
;; Maintainer : Malcolm Matalka <malcolm@terrateam.io>
;; Package-Requires: ((emacs "29.1") tuareg)
;; Created    : January 2024
;; Keywords   : ocaml languages tree-sitter

;;; Commentary:
;;

;;; Code:

(require 'treesit)

(declare-function treesit-parser-create "treesit.c")
(declare-function treesit-induce-sparse-tree "treesit.c")
(declare-function treesit-node-start "treesit.c")
(declare-function treesit-node-type "treesit.c")
(declare-function treesit-node-child-by-field-name "treesit.c")

(defvar ocaml-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?_ "_" table)
    (modify-syntax-entry ?# "." table)
    (modify-syntax-entry ?? ". p" table)
    (modify-syntax-entry ?~ ". p" table)
    (dolist (c '(?! ?$ ?% ?& ?+ ?- ?/ ?: ?< ?= ?> ?@ ?^ ?|))
      (modify-syntax-entry c "." table))
    (modify-syntax-entry ?' "_" table) ; ' is part of symbols (for primes).
    (modify-syntax-entry ?\" "\"" table) ; " is a string delimiter
    (modify-syntax-entry ?\\ "\\" table)
    (modify-syntax-entry ?*  ". 23" table)
    (modify-syntax-entry ?\( "()1n" table)
    (modify-syntax-entry ?\) ")(4n" table)
    table)
  "Syntax table for `ocaml-ts-mode'.")

(defvar ocaml-ts-mode--keywords
  '("and"
    "as"
    "assert"
    ;; "asr"
    "begin"
    "class"
    "constraint"
    "do"
    "done"
    "downto"
    "effect"
    "else"
    "end"
    "exception"
    "external"
    ;; "false"
    "for"
    "fun"
    "function"
    "functor"
    "if"
    "in"
    "include"
    "inherit"
    "initializer"
    ;; "land"
    "lazy"
    "let"
    ;; "lour"
    ;; "lsl"
    ;; "lsr"
    ;; "lxor"
    "match"
    "method"
    ;; "mod"
    "module"
    "mutable"
    "new"
    "nonrec"
    "object"
    "of"
    "open"
    ;; "or"
    "private"
    "rec"
    "sig"
    "struct"
    "then"
    "to"
    ;; "true"
    "try"
    "type"
    "val"
    "virtual"
    "when"
    "while"
    "with")
  "Ocaml keywords for tree-sitter font-locking.")

(defun ocaml-ts-mode--font-lock-settings (language)
  (treesit-font-lock-rules
   :language language
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language language
   :feature 'constant
   '((constructor_name) @font-lock-constant-face
     (module_name) @font-lock-type-face
     (tag) @font-lock-constant-face
     (boolean) @font-lock-constant-face)

   :language language
   :feature 'bracket
   '((["(" ")" "[" "]" "{" "}"]) @font-lock-bracket-face)

   :language language
   :feature 'delimiter
   '((["," "." ";" ":" ";;"]) @font-lock-delimiter-face)

   :language language
   :feature 'keyword
   `([,@ocaml-ts-mode--keywords] @font-lock-keyword-face)

   :language language
   :feature 'definition
   '((let_binding pattern: (value_name) @font-lock-function-name-face))

   :language language
   :feature 'variable
   '((value_name) @font-lock-variable-use-face
     (field_name) @font-lock-variable-use-face)

   :language language
   :feature 'ppx
   '((attribute_id) @font-lock-function-call-face)

   :language language
   :feature 'function
   :override t
   '((application_expression function: (value_path (value_name) @font-lock-function-call-face))
     (application_expression function: (value_path (module_path (_) @font-lock-type-face) (value_name) @font-lock-function-call-face)))

   :language language
   :feature 'number
   '((number) @font-lock-number-face)

   :language language
   :feature 'string
   '((string) @font-lock-string-face
     (character) @font-lock-string-face)

   :language language
   :feature 'escape-sequence
   :override t
   '((escape_sequence) @font-lock-escape-face)

   :language language
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face)))

;; TODO Move this into tuareg / top-level OCaml mode
(defun tuareg-smie-setup ()
  (progn
    (setq-local syntax-propertize-function #'tuareg-syntax-propertize)
    (setq-local parse-sexp-ignore-comments t)
    (smie-setup tuareg-smie-grammar #'tuareg-smie-rules
                :forward-token #'tuareg-smie-forward-token
                :backward-token #'tuareg-smie-backward-token)
    (when (boundp 'smie--hanging-eolp-function)
      ;; FIXME: As its name implies, smie--hanging-eolp-function
      ;; is not to be used by packages like us, but SMIE's maintainer
      ;; hasn't provided any alternative so far :-(
      (add-function :before (local 'smie--hanging-eolp-function)
                    #'tuareg--hanging-eolp-advice))
    (add-function :around (local 'indent-line-function)
                  #'tuareg--indent-line)
    (add-hook 'smie-indent-functions #'tuareg-smie--args nil t)
    (add-hook 'smie-indent-functions #'tuareg-smie--inside-string nil t)))

;;;###autoload
(define-derived-mode ocaml-ts-mode prog-mode "OCaml"
  "Major mode for editing Ocaml, powered by tree-sitter."
  :group 'ocaml
  :syntax-table ocaml-ts-mode--syntax-table

  (unless (treesit-ready-p 'ocaml)
    (error "Tree-sitter for OCAML isn't available"))

  (treesit-parser-create 'ocaml)

  ;; Indent.
  (tuareg-smie-setup)

  (setq-local comment-start "(* ")
  (setq-local comment-end " *)")
  (setq-local comment-start-skip "(\\*+[ \t]*")

  ;; Font-lock.
  (setq-local treesit-font-lock-settings (ocaml-ts-mode--font-lock-settings 'ocaml))
  (setq-local treesit-font-lock-feature-list
              '((comment number string)
                (keyword constant)
                (escape-sequence function variable definition ppx)
                (bracket delimiter error)))

  (setq-local treesit-language-at-point-function
              (lambda (_pos) 'ocaml))

  (treesit-major-mode-setup))

;;;###autoload
(define-derived-mode ocamli-ts-mode prog-mode "OCamli"
  "Major mode for editing Ocaml interfaces, powered by tree-sitter."
  :group 'ocaml
  :syntax-table ocaml-ts-mode--syntax-table

  (unless (treesit-ready-p 'ocaml-interface)
    (error "Tree-sitter for ocaml interface isn't available"))

  (treesit-parser-create 'ocaml-interface)

  ;; Indent.
  (tuareg-smie-setup)
  
  (setq-local comment-start "(* ")
  (setq-local comment-end " *)")
  (setq-local comment-start-skip "(\\*+[ \t]*")

  ;; Font-lock.
  (setq-local treesit-font-lock-settings (ocaml-ts-mode--font-lock-settings 'ocaml-interface))
  (setq-local treesit-font-lock-feature-list
              '((comment number string)
                (keyword constant)
                (escape-sequence function variable definition ppx)
                (bracket delimiter error)))

  (setq-local treesit-language-at-point-function
              (lambda (_pos) 'ocaml-interface))

  (treesit-major-mode-setup))

;; NOTE: auto-mode-alist modifications are commented out because ocaml-ts-mode
;; is used as a library by tuareg-mode for tree-sitter support, not as a
;; standalone mode. Users should use tuareg-mode with tuareg-mode-treesitter-derive
;; set to t to get tree-sitter support.
;;
;; ;;;###autoload
;; (progn
;;   (add-to-list 'auto-mode-alist '("\\.ml\\'" . ocaml-ts-mode))
;;   (add-to-list 'auto-mode-alist '("\\.mli\\'" . ocamli-ts-mode)))

(provide 'ocaml-ts-mode)

;;; ocaml-ts-mode.el ends here