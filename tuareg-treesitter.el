;;; tuareg-treesitter.el --- use native ocaml-ts-mode -*-lexical-binding: t-*-
;;; Commentary:

;; Derive from ocaml-ts-mode instead of prog-mode

;;; Code:
(require 'tuareg)

(when (version<= "29.1" emacs-version)
  (require 'treesit)
  (require 'ocaml-ts-mode))

(provide 'tuareg-treesitter)
;;; taureg-treesitter.el ends here
