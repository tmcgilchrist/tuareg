;;; tuareg-treesitter.el --- Tree-sitter parser bridge for Tuareg  -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Free Software Foundation, Inc.

;; Author: Tim McGilchrist <timmcgil@gmail.com>
;; Keywords: languages, ocaml, tree-sitter
;; Package-Requires: ((emacs "29.1") (tuareg "3.0"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; A small, self-contained add-on for `tuareg-mode' that creates a
;; Tree-sitter parser in every Tuareg buffer, choosing the grammar
;; from the file type:
;;
;;   * `ocaml'            for implementation files (.ml, .mlp, .eliom)
;;   * `ocaml-interface'  for interface files      (.mli, .eliomi)
;;
;; That is all tools such as Combobulate need: they select their
;; ruleset from the buffer's parser language (`treesit-parser-language'),
;; so once the right parser exists everything else follows.
;;
;; Usage:
;;
;; Minimal setup -- load the bridge after tuareg, then install the
;; grammars once with `M-x tuareg-treesitter-install-grammars':
;;
;;   (with-eval-after-load 'tuareg
;;     (require 'tuareg-treesitter))
;;
;; With `use-package' (Emacs 29+), fetching the `ocaml' and
;; `ocaml-interface' grammars automatically the first time a Tuareg
;; buffer is visited and they are missing:
;;
;;   (use-package tuareg
;;     :config
;;     (require 'tuareg-treesitter)
;;     ;; Compile any missing OCaml grammars on demand.  The first time
;;     ;; this runs it needs Git and a C compiler and may take a few
;;     ;; seconds; afterwards the grammars are cached and it is a no-op.
;;     (setq tuareg-treesitter-install-missing-grammars t))
;;
;; The grammars are pinned in `tuareg-treesitter-language-source-alist';
;; customise it before the first install to track a different revision.

;;; Code:

(require 'tuareg)
(require 'treesit nil t)
(require 'seq)

(declare-function treesit-available-p "treesit.c")
(declare-function treesit-parser-create "treesit.c")
(declare-function treesit-parser-list "treesit.c")
(declare-function treesit-parser-language "treesit.c")
(declare-function treesit-ready-p "treesit")
(declare-function treesit-language-available-p "treesit")
(declare-function treesit-install-language-grammar "treesit")
(declare-function treesit-node-check "treesit.c")
(declare-function treesit-node-type "treesit.c")
(declare-function treesit-node-text "treesit")
(declare-function treesit-node-parent "treesit.c")
(declare-function treesit-node-child-by-field-name "treesit.c")
(declare-function treesit-node-top-level "treesit")
(declare-function treesit-search-subtree "treesit")
(declare-function treesit-simple-imenu "treesit")

(defgroup tuareg-treesitter nil
  "Create Tree-sitter parsers in Tuareg buffers."
  :group 'tuareg
  :prefix "tuareg-treesitter-")

(defconst tuareg-treesitter-language-source-alist
  '((ocaml
     "https://github.com/tree-sitter/tree-sitter-ocaml"
     "v0.24.2" "grammars/ocaml/src")
    (ocaml-interface
     "https://github.com/tree-sitter/tree-sitter-ocaml"
     "v0.24.2" "grammars/interface/src"))
  "Tree-sitter grammar sources required by Tuareg.
Each entry has the form (LANG URL REVISION SOURCE-DIR), suitable for
`treesit-language-source-alist'.")

(defcustom tuareg-treesitter-enable t
  "Whether to auto-create a Tree-sitter parser in Tuareg buffers."
  :type 'boolean)

(defcustom tuareg-treesitter-install-missing-grammars nil
  "If non-nil, install missing OCaml grammars automatically.
When nil, missing grammars are left alone; install them yourself with
\\[tuareg-treesitter-install-grammars]."
  :type 'boolean)

(defcustom tuareg-treesitter-imenu t
  "If non-nil, build the Imenu index from the Tree-sitter tree.
This replaces Tuareg's own regexp-based Imenu index with one derived
from the OCaml parse tree.  Set to nil to keep Tuareg's index."
  :type 'boolean)

(defconst tuareg-treesitter--interface-file-regexp
  (rx "." (or "mli" "eliomi") eos)
  "Regexp matching the file names of OCaml interface files.
This also matches names such as \"foo.pp.mli\".")

(defun tuareg-treesitter-buffer-language ()
  "Return the OCaml Tree-sitter language symbol for the current buffer.
This is `ocaml-interface' for interface files and `ocaml' otherwise."
  (if (and buffer-file-name
           (string-match-p tuareg-treesitter--interface-file-regexp
                           buffer-file-name))
      'ocaml-interface
    'ocaml))

(defun tuareg-treesitter--register-sources ()
  "Add the OCaml grammars to `treesit-language-source-alist' if absent."
  (dolist (src tuareg-treesitter-language-source-alist)
    (unless (assq (car src) treesit-language-source-alist)
      (add-to-list 'treesit-language-source-alist src))))

(defun tuareg-treesitter--maybe-install (lang)
  "Install grammar for LANG when missing and allowed by customization."
  (when (and tuareg-treesitter-install-missing-grammars
             (not (treesit-language-available-p lang)))
    (tuareg-treesitter--register-sources)
    (ignore-errors (treesit-install-language-grammar lang))))

;;;###autoload
(defun tuareg-treesitter-install-grammars (&optional force)
  "Install the OCaml Tree-sitter grammars used by Tuareg.
Only missing grammars are installed unless FORCE (the prefix argument)
is non-nil, in which case every grammar is reinstalled."
  (interactive "P")
  (unless (and (fboundp 'treesit-available-p) (treesit-available-p))
    (user-error "This Emacs build has no Tree-sitter support"))
  (tuareg-treesitter--register-sources)
  (let (installed)
    (dolist (src tuareg-treesitter-language-source-alist)
      (let ((lang (car src)))
        (when (or force (not (treesit-language-available-p lang)))
          (message "Installing Tree-sitter grammar for %s..." lang)
          (treesit-install-language-grammar lang)
          (push lang installed))))
    (if installed
        (message "Installed OCaml grammars: %s"
                 (mapconcat #'symbol-name (nreverse installed) ", "))
      (message "All OCaml Tree-sitter grammars are already installed"))))

;;;; Imenu (Tree-sitter)

;; A Tree-sitter Imenu index, modelled on `neocaml-mode'.  We drive
;; `treesit-simple-imenu' directly rather than going through
;; `treesit-major-mode-setup', so Tuareg keeps its own font-lock,
;; indentation and defun navigation untouched.

(defconst tuareg-treesitter--nested-context-regexp
  (regexp-opt '("let_expression"
                "parenthesized_module_expression"
                "package_expression")
              'symbols)
  "Node types marking a nested (non-top-level) context.")

(defun tuareg-treesitter--subtree-text (node type &optional depth)
  "Return the text of the first TYPE node within NODE's subtree.
Search up to DEPTH levels deep (default 1); return nil if not found."
  (when-let* ((child (treesit-search-subtree node type nil nil (or depth 1))))
    (treesit-node-text child t)))

(defun tuareg-treesitter--defun-valid-p (node)
  "Return non-nil when NODE is a top-level definition.
Definitions nested inside a `let_expression', a parenthesized module
expression or a package expression are skipped."
  (and (treesit-node-check node 'named)
       (not (treesit-node-top-level
             node tuareg-treesitter--nested-context-regexp))))

(defun tuareg-treesitter--defun-name (node)
  "Return the name of definition NODE, or nil when it has none."
  (pcase (treesit-node-type node)
    ("type_binding"
     (treesit-node-text (treesit-node-child-by-field-name node "name") t))
    ("module_binding"
     (tuareg-treesitter--subtree-text node "module_name"))
    ("module_type_definition"
     (tuareg-treesitter--subtree-text node "module_type_name"))
    ("class_binding"
     (tuareg-treesitter--subtree-text node "class_name"))
    ("class_type_binding"
     (tuareg-treesitter--subtree-text node "class_type_name"))
    ("method_definition"
     (tuareg-treesitter--subtree-text node "method_name"))
    ("method_specification"
     (tuareg-treesitter--subtree-text node "method_name"))
    ("instance_variable_definition"
     (tuareg-treesitter--subtree-text node "instance_variable_name"))
    ("instance_variable_specification"
     (tuareg-treesitter--subtree-text node "instance_variable_name"))
    ("exception_definition"
     (tuareg-treesitter--subtree-text node "constructor_name" 2))
    ("external"
     (tuareg-treesitter--subtree-text node "value_name"))
    ("value_specification"
     (tuareg-treesitter--subtree-text node "value_name"))
    ("let_binding"
     (treesit-node-text (treesit-node-child-by-field-name node "pattern") t))))

(defun tuareg-treesitter--imenu-name (node)
  "Return NODE's name for Imenu, qualified with enclosing definitions.
Ancestor names are joined with `treesit-add-log-defun-delimiter'."
  (let ((name nil))
    (while node
      (when-let* ((new (tuareg-treesitter--defun-name node)))
        (setq name (if name
                       (concat new treesit-add-log-defun-delimiter name)
                     new)))
      (setq node (treesit-node-parent node)))
    name))

(defconst tuareg-treesitter--imenu-settings
  '(("Type" "\\`type_binding\\'"
     tuareg-treesitter--defun-valid-p tuareg-treesitter--imenu-name)
    ("Exception" "\\`exception_definition\\'"
     tuareg-treesitter--defun-valid-p tuareg-treesitter--imenu-name)
    ("Value" "\\`\\(?:let_binding\\|external\\)\\'"
     tuareg-treesitter--defun-valid-p tuareg-treesitter--imenu-name)
    ("Method" "\\`method_definition\\'"
     tuareg-treesitter--defun-valid-p tuareg-treesitter--imenu-name)
    ("Module" "\\`\\(?:module_binding\\|module_type_definition\\)\\'"
     tuareg-treesitter--defun-valid-p tuareg-treesitter--imenu-name)
    ("Class" "\\`\\(?:class_binding\\|class_type_binding\\)\\'"
     tuareg-treesitter--defun-valid-p tuareg-treesitter--imenu-name))
  "`treesit-simple-imenu-settings' for OCaml implementation files.")

(defconst tuareg-treesitter--interface-imenu-settings
  '(("Type" "\\`type_binding\\'"
     tuareg-treesitter--defun-valid-p tuareg-treesitter--imenu-name)
    ("Val" "\\`value_specification\\'"
     tuareg-treesitter--defun-valid-p tuareg-treesitter--imenu-name)
    ("External" "\\`external\\'"
     tuareg-treesitter--defun-valid-p tuareg-treesitter--imenu-name)
    ("Exception" "\\`exception_definition\\'"
     tuareg-treesitter--defun-valid-p tuareg-treesitter--imenu-name)
    ("Method" "\\`method_specification\\'"
     tuareg-treesitter--defun-valid-p tuareg-treesitter--imenu-name)
    ("Module" "\\`\\(?:module_binding\\|module_type_definition\\)\\'"
     tuareg-treesitter--defun-valid-p tuareg-treesitter--imenu-name)
    ("Class" "\\`\\(?:class_binding\\|class_type_binding\\)\\'"
     tuareg-treesitter--defun-valid-p tuareg-treesitter--imenu-name))
  "`treesit-simple-imenu-settings' for OCaml interface files.")

(defun tuareg-treesitter--setup-imenu (lang)
  "Use a Tree-sitter Imenu index for LANG in the current buffer."
  (setq-local treesit-simple-imenu-settings
              (if (eq lang 'ocaml-interface)
                  tuareg-treesitter--interface-imenu-settings
                tuareg-treesitter--imenu-settings))
  (setq-local imenu-create-index-function #'treesit-simple-imenu))

(defun tuareg-treesitter-setup ()
  "Create a Tree-sitter parser in the current Tuareg buffer.
Chooses the grammar from the file type (see
`tuareg-treesitter-buffer-language').  Safe to call repeatedly:
`treesit-parser-create' reuses an existing parser for the language.

When `tuareg-treesitter-imenu' is non-nil, also replace Tuareg's
Imenu index with a Tree-sitter one.

Intended for `tuareg-mode-hook'."
  (when (and tuareg-treesitter-enable
             (fboundp 'treesit-available-p)
             (treesit-available-p))
    (let ((lang (tuareg-treesitter-buffer-language)))
      (tuareg-treesitter--maybe-install lang)
      (when (treesit-ready-p lang t)
        (treesit-parser-create lang)
        ;; Make `treesit-language-at' (and thus Combobulate's
        ;; `combobulate-primary-language') unambiguous in this buffer.
        (setq-local treesit-language-at-point-function
                    (lambda (_pos) lang))
        (when tuareg-treesitter-imenu
          (tuareg-treesitter--setup-imenu lang))))))

(add-hook 'tuareg-mode-hook #'tuareg-treesitter-setup)

(provide 'tuareg-treesitter)
;;; tuareg-treesitter.el ends here
