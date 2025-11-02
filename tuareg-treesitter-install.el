;;; tuareg-treesitter-install.el --- Install tree-sitter grammars  -*- lexical-binding: t; -*-

;;; Commentary:

;; Simple helper to install tree-sitter grammars for tuareg modes.

;;; Code:

(require 'treesit)

;; TODO: Update these URLs to point to official repositories once they are available
;; Currently using tmcgilchrist's repos for development (menhir, ocamllex, opam)
(defvar tuareg-treesitter-grammars
  '((ocaml "https://github.com/tree-sitter/tree-sitter-ocaml" nil "grammars/ocaml/src")
    (ocaml-interface "https://github.com/tree-sitter/tree-sitter-ocaml" nil "grammars/interface/src")
    (ocaml-type "https://github.com/tree-sitter/tree-sitter-ocaml" nil "grammars/type/src")
    (menhir "https://github.com/tmcgilchrist/tree-sitter-menhir" nil "src")
    (ocamllex "https://github.com/tmcgilchrist/tree-sitter-ocamllex" nil "src")
    (opam "https://github.com/tmcgilchrist/tree-sitter-opam" nil "src"))
  "List of tree-sitter grammars needed for tuareg.
Format: (LANGUAGE REPO-URL REVISION SOURCE-DIR)")

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
