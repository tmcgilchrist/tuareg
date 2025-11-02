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
  ;; Check if all three OCaml grammars are available
  (let ((missing-grammars '()))
    (dolist (lang '(ocaml ocaml-interface ocaml-type))
      (unless (treesit-ready-p lang)
        (push lang missing-grammars)))

    (when missing-grammars
      (if (and (require 'tuareg-treesitter-install nil t)
               (yes-or-no-p (format "Tree-sitter grammars missing: %s. Install them now? "
                                    (mapconcat #'symbol-name (nreverse missing-grammars) ", "))))
          (progn
            (tuareg-treesitter--install-grammars-noninteractive)
            ;; Re-check after installation
            (dolist (lang '(ocaml ocaml-interface ocaml-type))
              (unless (treesit-ready-p lang)
                (error "Failed to install tree-sitter grammar for %s" lang))))
        (error "Tree-sitter for OCaml isn't available. Run M-x tuareg-treesitter-install-grammars"))))

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
