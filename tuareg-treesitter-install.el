;;; tuareg-treesitter-install.el --- Install tree-sitter grammars  -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Free Software Foundation, Inc.

;; Author: Tim McGilchrist <timmcgil@gmail.com>

;;; Commentary:

;; Simple helper to install tree-sitter grammars for tuareg modes.
;;
;; This module handles tree-sitter grammar installation using ABI 14
;; for maximum compatibility across Emacs versions.
;;
;; BRANCHING STRATEGY AND ABI COMPATIBILITY:
;;
;; Tree-sitter ABI support depends on which tree-sitter library version
;; Emacs was built against, NOT the Emacs version number:
;;
;; - tree-sitter 0.20.x - 0.24.x: supports ABI 13-14
;; - tree-sitter 0.25.x: supports ABI 13-15
;;
;; Both Emacs 29.x and 30.x can support different ABI ranges depending on
;; their build configuration. For maximum compatibility, we use ABI 14:
;;
;; - Works with all tested Emacs 29.x builds
;; - Works with all tested Emacs 30.x builds (even those built with 0.25.x)
;; - More portable than ABI 15 (which requires 0.25.x)
;;
;; BRANCH USAGE:
;; - `emacs-29` branch: Grammars regenerated with --abi=14 for compatibility
;; - `master` branch: May use ABI 15 (future, when universally supported)
;;
;; This applies to: tree-sitter-menhir, tree-sitter-dune, tree-sitter-opam
;; OCaml grammars use v0.24.2 tag which provides ABI 14 compatibility.

;;; Code:

(require 'treesit)

;; TODO: Update these URLs to point to official repositories once they are available
;; Currently using tmcgilchrist's repos for development (menhir, ocamllex, opam)
(defvar tuareg-treesitter-grammars
  `((ocaml "https://github.com/tree-sitter/tree-sitter-ocaml" "v0.24.2" "grammars/ocaml/src")
    (ocaml_interface "https://github.com/tree-sitter/tree-sitter-ocaml" "v0.24.2" "grammars/interface/src")
    (ocaml_type "https://github.com/tree-sitter/tree-sitter-ocaml" "v0.24.2" "grammars/type/src")

    (menhir "https://github.com/tmcgilchrist/tree-sitter-menhir" "emacs-29" "src")
    (dune "https://github.com/tmcgilchrist/tree-sitter-dune" "emacs-29" "src")
    (ocamllex "https://github.com/tmcgilchrist/tree-sitter-ocamllex" "master" "src")
    (opam "https://github.com/tmcgilchrist/tree-sitter-opam" "emacs-29" "src"))
  "List of tree-sitter grammars needed for tuareg.
Format: (LANGUAGE REPO-URL REVISION SOURCE-DIR)

The REVISION field specifies which branch/tag to use. We use 'emacs-29'
branches for grammars regenerated with ABI 14 for maximum compatibility.
See Commentary section for details on ABI compatibility strategy.")

(defun tuareg-treesitter--install-grammars-noninteractive ()
  "Install missing tree-sitter grammars without prompting.
Used internally by modes that have already prompted the user."
  (unless (version<= "29.1" emacs-version)
    (user-error "Tree-sitter requires Emacs 29.1 or later"))

  ;; Add our grammars to the source list
  (dolist (grammar tuareg-treesitter-grammars)
    (unless (assq (car grammar) treesit-language-source-alist)
      (push grammar treesit-language-source-alist)))

  ;; Install all missing grammars
  (dolist (grammar tuareg-treesitter-grammars)
    (let ((lang (car grammar)))
      (unless (treesit-language-available-p lang)
        (message "Installing %s..." lang)
        (treesit-install-language-grammar lang)))))

(defun tuareg-treesitter-install-grammars ()
  "Install missing tree-sitter grammars for tuareg.
Checks which grammars are available and offers to install missing ones."
  (interactive)
  (unless (version<= "29.1" emacs-version)
    (user-error "Tree-sitter requires Emacs 29.1 or later"))

  ;; Add our grammars to the source list
  (dolist (grammar tuareg-treesitter-grammars)
    (unless (assq (car grammar) treesit-language-source-alist)
      (push grammar treesit-language-source-alist)))

  ;; Check what's missing
  (let ((missing '()))
    (dolist (grammar tuareg-treesitter-grammars)
      (unless (treesit-language-available-p (car grammar))
        (push (car grammar) missing)))

    (if (null missing)
        (message "All tuareg tree-sitter grammars are installed!")
      (when (yes-or-no-p
             (format "Missing grammars: %s. Install them? "
                     (mapconcat #'symbol-name (nreverse missing) ", ")))
        (dolist (lang (nreverse missing))
          (message "Installing %s..." lang)
          (treesit-install-language-grammar lang))
        (message "Installation complete!")))))

(provide 'tuareg-treesitter-install)

;;; tuareg-treesitter-install.el ends here
