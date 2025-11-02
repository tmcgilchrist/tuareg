;;; tuareg-treesitter-install.el --- Install tree-sitter grammars  -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Free Software Foundation, Inc.

;; Author: Tim McGilchrist <timmcgil@gmail.com>

;;; Commentary:

;; Simple helper to install tree-sitter grammars for tuareg modes.
;;
;; This module handles tree-sitter grammar installation with support for
;; both Emacs 29.x (ABI 14) and Emacs 30+ (ABI 15).
;;
;; BRANCHING STRATEGY:
;;
;; Tree-sitter grammars must be compiled with the correct ABI version:
;; - Emacs 29.x requires ABI 14 (tree-sitter library 0.22.x)
;; - Emacs 30+ requires ABI 15 (tree-sitter library 0.25.x)
;;
;; To support both Emacs versions, we maintain dual branches for some grammars:
;; - `emacs-29` branch: Uses tree-sitter 0.22.x for ABI 14 compatibility
;; - `master` branch: Uses tree-sitter 0.25.x for ABI 15 (latest features)
;;
;; This applies to: tree-sitter-menhir, tree-sitter-opam
;; OCaml and OCamllex grammars already use 0.22.4 and work on both versions.

;;; Code:

(require 'treesit)

;; TODO: Update these URLs to point to official repositories once they are available
;; Currently using tmcgilchrist's repos for development (menhir, ocamllex, opam)
(defvar tuareg-treesitter-grammars
  `((ocaml "https://github.com/tree-sitter/tree-sitter-ocaml" "v0.24.2" "grammars/ocaml/src")
    (ocaml-interface "https://github.com/tree-sitter/tree-sitter-ocaml" "v0.24.2" "grammars/interface/src")
    (ocaml-type "https://github.com/tree-sitter/tree-sitter-ocaml" "v0.24.2" "grammars/type/src")
    ;; Menhir: Use emacs-29 branch for Emacs 29.x (ABI 14), master for Emacs 30+ (ABI 15)
    (menhir "https://github.com/tmcgilchrist/tree-sitter-menhir"
            ,(if (version< emacs-version "30") "emacs-29" nil)
            "src")
    (ocamllex "https://github.com/tmcgilchrist/tree-sitter-ocamllex" nil "src")
    ;; Opam: Use emacs-29 branch for Emacs 29.x (ABI 14), master for Emacs 30+ (ABI 15)
    (opam "https://github.com/tmcgilchrist/tree-sitter-opam"
          ,(if (version< emacs-version "30") "emacs-29" nil)
          "src"))
  "List of tree-sitter grammars needed for tuareg.
Format: (LANGUAGE REPO-URL REVISION SOURCE-DIR)

The REVISION field is dynamically selected based on Emacs version to ensure
correct ABI compatibility. See Commentary section for branching strategy.")

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
