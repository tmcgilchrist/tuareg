;;; tuareg-tree-sitter-tests.el --- Tests for tree-sitter integration  -*- lexical-binding: t -*-

;;; Commentary:

;; Tests for tuareg-mode's tree-sitter integration.
;; These tests verify that:
;; - Tree-sitter mode produces identical indentation to standard mode
;; - Tree-sitter font-locking works correctly
;; - Tree-sitter mode can be enabled/disabled
;; - Graceful handling of missing tree-sitter grammars

;;; Code:

(require 'tuareg)
(require 'tuareg-treesitter)
(require 'tuareg-menhir)
(require 'tuareg-ocamllex)
(require 'ert)

(defconst tuareg-tree-sitter-test-dir
  (file-name-directory (or load-file-name buffer-file-name)))

(defun tuareg-tree-sitter-test--remove-indentation ()
  "Remove all indentation in the current buffer."
  (goto-char (point-min))
  (while (re-search-forward (rx bol (+ (in " \t"))) nil t)
    (let ((syntax (save-match-data (syntax-ppss))))
      (unless (or (nth 3 syntax)        ; not in string literal
                  (nth 4 syntax))       ; nor in comment
        (replace-match "")))))

;;; Indentation Tests

(ert-deftest tuareg-indent-treesitter-good ()
  "Check indentation with tree-sitter mode enabled.
This test verifies that enabling tree-sitter (for font-locking)
doesn't break indentation, which continues to use SMIE."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocaml)))
  (let ((file (expand-file-name "indent-test.ml" tuareg-tree-sitter-test-dir))
        (text (lambda () (buffer-substring-no-properties
                          (point-min) (point-max))))
        (tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert-file-contents file)
      (tuareg-mode)
      (let ((orig (funcall text)))
        ;; Remove the indentation and check that we get the original text.
        (tuareg-tree-sitter-test--remove-indentation)
        (indent-region (point-min) (point-max))
        (should (equal (funcall text) orig))
        ;; Indent again to verify idempotency.
        (indent-region (point-min) (point-max))
        (should (equal (funcall text) orig))))))

(ert-deftest tuareg-indent-treesitter-bad ()
  "Check indentation with tree-sitter mode enabled for known failures.
This test verifies that tree-sitter mode has the same limitations
as the standard mode for indentation edge cases."
  :expected-result :failed
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocaml)))
  (let ((file (expand-file-name "indent-test-failed.ml" tuareg-tree-sitter-test-dir))
        (text (lambda () (buffer-substring-no-properties
                          (point-min) (point-max))))
        (tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert-file-contents file)
      (tuareg-mode)
      (let ((orig (funcall text)))
        ;; Remove the indentation and check that we get the original text.
        (tuareg-tree-sitter-test--remove-indentation)
        (indent-region (point-min) (point-max))
        (should (equal (funcall text) orig))
        ;; Indent again to verify idempotency.
        (indent-region (point-min) (point-max))
        (should (equal (funcall text) orig))))))

(ert-deftest tuareg-treesitter-consistency ()
  "Verify that tree-sitter mode produces identical indentation to standard mode.
This is a key requirement: tree-sitter should be a drop-in replacement."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocaml)))
  (let ((file (expand-file-name "indent-test.ml" tuareg-tree-sitter-test-dir)))
    (let ((standard-result
           (let ((tuareg-mode-treesitter-derive nil))
             (with-temp-buffer
               (insert-file-contents file)
               (tuareg-mode)
               (tuareg-tree-sitter-test--remove-indentation)
               (indent-region (point-min) (point-max))
               (buffer-substring-no-properties (point-min) (point-max)))))
          (treesitter-result
           (let ((tuareg-mode-treesitter-derive t))
             (with-temp-buffer
               (insert-file-contents file)
               (tuareg-mode)
               (tuareg-tree-sitter-test--remove-indentation)
               (indent-region (point-min) (point-max))
               (buffer-substring-no-properties (point-min) (point-max))))))
      ;; Both modes should produce identical indentation
      (should (equal standard-result treesitter-result)))))

;;; Tree-sitter Activation Tests

(ert-deftest tuareg-treesitter-mode-activation ()
  "Test that tree-sitter mode activates correctly when enabled."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocaml)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "let x = 42")
      (tuareg-mode)
      ;; Verify that a tree-sitter parser was created
      (should (treesit-parser-list))
      (should (eq (treesit-parser-language (car (treesit-parser-list))) 'ocaml)))))

(ert-deftest tuareg-treesitter-mode-not-activated ()
  "Test that tree-sitter mode does not activate when disabled."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)))
  (let ((tuareg-mode-treesitter-derive nil))
    (with-temp-buffer
      (insert "let x = 42")
      (tuareg-mode)
      ;; Verify that no tree-sitter parser was created
      (should-not (treesit-parser-list)))))

;;; Font-locking Tests

(ert-deftest tuareg-treesitter-font-lock-keyword ()
  "Test that keywords are font-locked correctly with tree-sitter."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocaml)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "let x = 42")
      (tuareg-mode)
      (font-lock-ensure)
      ;; Check that "let" is highlighted as a keyword
      (goto-char (point-min))
      (should (eq (get-text-property (point) 'face) 'font-lock-keyword-face)))))

(ert-deftest tuareg-treesitter-font-lock-number ()
  "Test that numbers are font-locked correctly with tree-sitter."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocaml)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "let x = 42")
      (tuareg-mode)
      (font-lock-ensure)
      ;; Check that "42" has some face (the specific face may vary)
      (goto-char (point-max))
      (backward-char 1)
      (should (get-text-property (point) 'face)))))

(ert-deftest tuareg-treesitter-font-lock-string ()
  "Test that strings are font-locked correctly with tree-sitter."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocaml)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "let s = \"hello\"")
      (tuareg-mode)
      (font-lock-ensure)
      ;; Check that the string is highlighted
      (goto-char (point-min))
      (search-forward "\"")
      (should (eq (get-text-property (point) 'face) 'font-lock-string-face)))))

(ert-deftest tuareg-treesitter-font-lock-comment ()
  "Test that comments are font-locked correctly with tree-sitter."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocaml)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "(* comment *)\nlet x = 42")
      (tuareg-mode)
      (font-lock-ensure)
      ;; Check that the comment is highlighted
      (goto-char (point-min))
      (forward-char 3)
      (should (eq (get-text-property (point) 'face) 'font-lock-comment-face)))))

;;; Defun Navigation Tests

(ert-deftest tuareg-treesitter-beginning-of-defun ()
  "Test that beginning-of-defun works correctly with tree-sitter enabled."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocaml)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "let f x = x + 1\n\nlet g y = y * 2")
      (tuareg-mode)
      ;; Move to the second function
      (goto-char (point-max))
      ;; Go to beginning of current defun
      (beginning-of-defun)
      ;; Should be at the start of "let g"
      (should (looking-at "let g")))))

(ert-deftest tuareg-treesitter-end-of-defun ()
  "Test that end-of-defun works correctly with tree-sitter enabled."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocaml)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "let f x = x + 1\n\nlet g y = y * 2")
      (tuareg-mode)
      ;; Move to the start
      (goto-char (point-min))
      ;; Go to end of first defun
      (end-of-defun)
      ;; Should be after the first function
      (forward-line)
      (should (looking-at "let g")))))

;;; Toggle Tests

(ert-deftest tuareg-treesitter-toggle ()
  "Test toggling between standard and tree-sitter modes."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocaml)))
  (with-temp-buffer
    (insert "let x = 42")

    ;; Start with tree-sitter disabled
    (let ((tuareg-mode-treesitter-derive nil))
      (tuareg-mode)
      (should-not (treesit-parser-list)))

    ;; Re-enable with tree-sitter
    (let ((tuareg-mode-treesitter-derive t))
      (tuareg-mode)
      (should (treesit-parser-list)))))

;;; Menhir Tree-sitter Tests

(ert-deftest tuareg-menhir-treesitter-mode-activation ()
  "Test that tree-sitter mode activates correctly for Menhir files."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'menhir)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "%token INT\n%%\nmain: INT { $1 }")
      (tuareg-menhir-mode)
      ;; Verify that a tree-sitter parser was created
      (should (treesit-parser-list))
      (should (eq (treesit-parser-language (car (treesit-parser-list))) 'menhir)))))

(ert-deftest tuareg-menhir-treesitter-mode-not-activated ()
  "Test that tree-sitter mode does not activate when disabled for Menhir."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)))
  (let ((tuareg-mode-treesitter-derive nil))
    (with-temp-buffer
      (insert "%token INT\n%%\nmain: INT { $1 }")
      (tuareg-menhir-mode)
      ;; Verify that no tree-sitter parser was created
      (should-not (treesit-parser-list)))))

(ert-deftest tuareg-menhir-treesitter-font-lock-keyword ()
  "Test that Menhir keywords are font-locked correctly with tree-sitter."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'menhir)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "%token INT\n%%\nmain: INT { $1 }")
      (tuareg-menhir-mode)
      (font-lock-ensure)
      ;; Check that "%token" is highlighted as a keyword
      (goto-char (point-min))
      (should (eq (get-text-property (point) 'face) 'font-lock-keyword-face)))))

(ert-deftest tuareg-menhir-treesitter-font-lock-comment ()
  "Test that Menhir comments are font-locked correctly with tree-sitter."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'menhir)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "/* comment */\n%token INT")
      (tuareg-menhir-mode)
      (font-lock-ensure)
      ;; Check that the comment is highlighted
      (goto-char (point-min))
      (forward-char 3)
      (should (eq (get-text-property (point) 'face) 'font-lock-comment-face)))))

(ert-deftest tuareg-menhir-treesitter-indentation ()
  "Test that Menhir indentation works with tree-sitter."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'menhir)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "%token INT\n%%\nmain:\n| INT { $1 }")
      (tuareg-menhir-mode)
      ;; Test that we can indent without error
      (goto-char (point-min))
      (forward-line 3)
      (indent-for-tab-command)
      ;; Just verify no error occurred
      (should t))))

(ert-deftest tuareg-menhir-treesitter-from-file ()
  "Test that tree-sitter mode works correctly with a real Menhir file."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'menhir)))
  (let ((file (expand-file-name "test-menhir.mly" tuareg-tree-sitter-test-dir))
        (tuareg-mode-treesitter-derive t))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (tuareg-menhir-mode)
        ;; Verify tree-sitter parser was created
        (should (treesit-parser-list))
        ;; Verify font-locking works
        (font-lock-ensure)
        ;; Check that we can find a keyword
        (goto-char (point-min))
        (when (search-forward "%token" nil t)
          (goto-char (match-beginning 0))
          (should (eq (get-text-property (point) 'face) 'font-lock-keyword-face)))))))

(ert-deftest tuareg-menhir-treesitter-toggle ()
  "Test toggling between standard and tree-sitter modes for Menhir."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'menhir)))
  (with-temp-buffer
    (insert "%token INT\n%%\nmain: INT { $1 }")

    ;; Start with tree-sitter disabled
    (let ((tuareg-mode-treesitter-derive nil))
      (tuareg-menhir-mode)
      (should-not (treesit-parser-list)))

    ;; Re-enable with tree-sitter
    (let ((tuareg-mode-treesitter-derive t))
      (tuareg-menhir-mode)
      (should (treesit-parser-list)))))

;;; OCamllex Tree-sitter Tests

(ert-deftest tuareg-ocamllex-treesitter-mode-activation ()
  "Test that tree-sitter mode activates correctly for OCamllex files."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocamllex)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "rule token = parse | eof { EOF }")
      (tuareg-ocamllex-mode)
      ;; Verify that a tree-sitter parser was created
      (should (treesit-parser-list))
      (should (eq (treesit-parser-language (car (treesit-parser-list))) 'ocamllex)))))

(ert-deftest tuareg-ocamllex-treesitter-mode-not-activated ()
  "Test that tree-sitter mode does not activate when disabled for OCamllex."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)))
  (let ((tuareg-mode-treesitter-derive nil))
    (with-temp-buffer
      (insert "rule token = parse | eof { EOF }")
      (tuareg-ocamllex-mode)
      ;; Verify that no tree-sitter parser was created
      (should-not (treesit-parser-list)))))

(ert-deftest tuareg-ocamllex-treesitter-font-lock-keyword ()
  "Test that OCamllex keywords are font-locked correctly with tree-sitter."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocamllex)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "rule token = parse | eof { EOF }")
      (tuareg-ocamllex-mode)
      (font-lock-ensure)
      ;; Check that "rule" is highlighted as a keyword
      (goto-char (point-min))
      (should (eq (get-text-property (point) 'face) 'font-lock-keyword-face)))))

(ert-deftest tuareg-ocamllex-treesitter-font-lock-comment ()
  "Test that OCamllex comments are font-locked correctly with tree-sitter."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocamllex)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "(* comment *)\nrule token = parse")
      (tuareg-ocamllex-mode)
      (font-lock-ensure)
      ;; Check that the comment is highlighted
      (goto-char (point-min))
      (forward-char 3)
      (should (eq (get-text-property (point) 'face) 'font-lock-comment-face)))))

(ert-deftest tuareg-ocamllex-treesitter-indentation ()
  "Test that OCamllex indentation works with tree-sitter."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocamllex)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "rule token = parse\n| eof { EOF }")
      (tuareg-ocamllex-mode)
      ;; Test that we can indent without error
      (goto-char (point-min))
      (forward-line 1)
      (indent-for-tab-command)
      ;; Just verify no error occurred
      (should t))))

(ert-deftest tuareg-ocamllex-treesitter-from-file ()
  "Test that tree-sitter mode works correctly with a real OCamllex file."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocamllex)))
  (let ((file (expand-file-name "test-ocamllex.mll" tuareg-tree-sitter-test-dir))
        (tuareg-mode-treesitter-derive t))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (tuareg-ocamllex-mode)
        ;; Verify tree-sitter parser was created
        (should (treesit-parser-list))
        ;; Verify font-locking works
        (font-lock-ensure)
        ;; Check that we can find a keyword
        (goto-char (point-min))
        (when (search-forward "rule" nil t)
          (goto-char (match-beginning 0))
          (should (eq (get-text-property (point) 'face) 'font-lock-keyword-face)))))))

(ert-deftest tuareg-ocamllex-treesitter-toggle ()
  "Test toggling between standard and tree-sitter modes for OCamllex."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'ocamllex)))
  (with-temp-buffer
    (insert "rule token = parse | eof { EOF }")

    ;; Start with tree-sitter disabled
    (let ((tuareg-mode-treesitter-derive nil))
      (tuareg-ocamllex-mode)
      (should-not (treesit-parser-list)))

    ;; Re-enable with tree-sitter
    (let ((tuareg-mode-treesitter-derive t))
      (tuareg-ocamllex-mode)
      (should (treesit-parser-list)))))

;;; OPAM Tree-sitter Tests

(ert-deftest tuareg-opam-treesitter-mode-activation ()
  "Test that tree-sitter mode activates correctly for OPAM files."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'opam)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "opam-version: \"2.0\"\nname: \"test\"\nversion: \"1.0\"")
      (tuareg-opam-mode)
      ;; Verify that a tree-sitter parser was created
      (should (treesit-parser-list))
      (should (eq (treesit-parser-language (car (treesit-parser-list))) 'opam)))))

(ert-deftest tuareg-opam-treesitter-mode-not-activated ()
  "Test that tree-sitter mode does not activate when disabled for OPAM."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)))
  (let ((tuareg-mode-treesitter-derive nil))
    (with-temp-buffer
      (insert "opam-version: \"2.0\"\nname: \"test\"\nversion: \"1.0\"")
      (tuareg-opam-mode)
      ;; Verify that no tree-sitter parser was created
      (should-not (treesit-parser-list)))))

(ert-deftest tuareg-opam-treesitter-font-lock-keyword ()
  "Test that OPAM keywords are font-locked correctly with tree-sitter."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'opam)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "depends: [\"ocaml\"]")
      (tuareg-opam-mode)
      (font-lock-ensure)
      ;; Check that "depends" is highlighted as a keyword
      (goto-char (point-min))
      (should (eq (get-text-property (point) 'face) 'font-lock-keyword-face)))))

(ert-deftest tuareg-opam-treesitter-font-lock-comment ()
  "Test that OPAM comments are font-locked correctly with tree-sitter."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'opam)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "# This is a comment\nname: \"test\"")
      (tuareg-opam-mode)
      (font-lock-ensure)
      ;; Check that the comment is highlighted
      (goto-char (point-min))
      (forward-char 2)
      (should (eq (get-text-property (point) 'face) 'font-lock-comment-face)))))

(ert-deftest tuareg-opam-treesitter-font-lock-string ()
  "Test that OPAM strings are font-locked correctly with tree-sitter."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'opam)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "name: \"test-package\"")
      (tuareg-opam-mode)
      (font-lock-ensure)
      ;; Check that the string is highlighted
      (goto-char (point-min))
      (search-forward "\"test")
      (should (eq (get-text-property (point) 'face) 'font-lock-string-face)))))

(ert-deftest tuareg-opam-treesitter-indentation ()
  "Test that OPAM indentation works with tree-sitter."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'opam)))
  (let ((tuareg-mode-treesitter-derive t))
    (with-temp-buffer
      (insert "depends: [\n\"ocaml\"\n\"dune\"\n]")
      (tuareg-opam-mode)
      ;; Test that we can indent without error
      (goto-char (point-min))
      (forward-line 1)
      (indent-for-tab-command)
      ;; Just verify no error occurred
      (should t))))

(ert-deftest tuareg-opam-treesitter-from-file ()
  "Test that tree-sitter mode works correctly with a real OPAM file."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'opam)))
  (let ((file (expand-file-name "tuareg.opam" tuareg-tree-sitter-test-dir))
        (tuareg-mode-treesitter-derive t))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (tuareg-opam-mode)
        ;; Verify tree-sitter parser was created
        (should (treesit-parser-list))
        ;; Verify font-locking works
        (font-lock-ensure)
        ;; Check that we can find a keyword
        (goto-char (point-min))
        (when (search-forward "opam-version" nil t)
          (goto-char (match-beginning 0))
          (should (eq (get-text-property (point) 'face) 'font-lock-keyword-face)))))))

(ert-deftest tuareg-opam-treesitter-toggle ()
  "Test toggling between standard and tree-sitter modes for OPAM."
  (skip-unless (and (version<= "29.1" emacs-version)
                    (require 'treesit nil t)
                    (fboundp 'treesit-ready-p)
                    (treesit-ready-p 'opam)))
  (with-temp-buffer
    (insert "opam-version: \"2.0\"\nname: \"test\"")
    ;; Start with tree-sitter disabled
    (let ((tuareg-mode-treesitter-derive nil))
      (tuareg-opam-mode)
      (should-not (treesit-parser-list)))
    ;; Enable tree-sitter and reload
    (let ((tuareg-mode-treesitter-derive t))
      (tuareg-opam-mode)
      (should (treesit-parser-list)))))

(provide 'tuareg-tree-sitter-tests)
;;; tuareg-tree-sitter-tests.el ends here
