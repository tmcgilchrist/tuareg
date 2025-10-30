;;; tuareg-treesitter.el --- Tree-sitter integration for tuareg-mode -*-lexical-binding: t-*-

;;; Commentary:

;; This file provides tree-sitter support for tuareg-mode.
;; When enabled via `tuareg-mode-treesitter-derive', it uses:
;; - Tree-sitter for syntax highlighting (more accurate)
;; - SMIE for indentation (proven and stable)
;;
;; This hybrid approach provides better highlighting while maintaining
;; the well-tested indentation behavior.

;;; Code:

(require 'tuareg)

(when (version<= "29.1" emacs-version)
  (require 'treesit)
  (require 'ocaml-ts-mode))

(defun tuareg-treesitter--setup ()
  "Set up tree-sitter support in the current tuareg-mode buffer.
This sets up tree-sitter for font-locking while keeping SMIE for indentation."
  (unless (treesit-ready-p 'ocaml)
    ;; TODO We should offer to install tree-sitter grammars here!
    (error "Tree-sitter for OCaml isn't available. Please install tree-sitter-ocaml"))

  ;; Create the tree-sitter parser
  (treesit-parser-create 'ocaml)

  ;; Set up SMIE indentation (proven to work)
  (tuareg--common-mode-setup)

  ;; Set up tree-sitter font-locking (more accurate than regex-based)
  (setq-local treesit-font-lock-settings
              (ocaml-ts-mode--font-lock-settings 'ocaml))
  (setq-local treesit-font-lock-feature-list
              '((comment number string)
                (keyword constant)
                (escape-sequence function variable definition ppx)
                (bracket delimiter error)))

  (setq-local treesit-language-at-point-function
              (lambda (_pos) 'ocaml))

  ;; Enable tree-sitter major mode setup (for font-locking)
  (treesit-major-mode-setup))

;; Note: The setup function should NOT be called at module load time.
;; It must be called from tuareg-mode's initialization code, in the context
;; of the buffer where tuareg-mode is being activated. Calling it here would
;; run it in the wrong buffer (the load buffer or *scratch*).

(provide 'tuareg-treesitter)
;;; tuareg-treesitter.el ends here
