;;; hyphen-ruby-mode.el --- major mode for editing Hyphen-Ruby scripts
;; Copyright (C) 2005  Daniel Brockman

;; Author: Daniel Brockman <daniel@brockman.se>
;; URL: <http://www.brockman.se/software/hyphen-ruby/>

;; This file is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2 of
;; the License, or (at your option) any later version.
;;
;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty
;; of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
;; See the GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public
;; License along with this file; if not, write to the Free
;; Software Foundation, 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; This mode adjusts the Font Lock tables and the syntax tables of the
;; ordinary Ruby mode so that hyphenated identifiers are treated well.

;; For example, ordinary Ruby mode treats `foo-bar' as two identifiers
;; and one minus operator.  Hyphen-Ruby mode treats the same string as
;; just a single identifier.

;; Put the text ``-*- Hyphen-Ruby -*-'' on the first lines of your
;; Hyphen-Ruby source files to have this mode enabled automatically.
;; Put this in your ~/.emacs to load this library automatically:

;; (autoload 'hyphen-ruby-mode "~/.elisp/hyphen-ruby-mode.el"
;;   "Major mode for editing Hyphen-Ruby scripts.
;; \\{ruby-mode-map}")

;;; Bugs:

;; Identifiers that contain, e.g., `class' screw up the indenting.

;;; Code:

(require 'ruby-mode)

;;;###autoload
(defun hyphen-ruby-mode ()
  "Major mode for editing Hyphen-Ruby scripts.
\\{ruby-mode-map}"
  (interactive)
  (ruby-mode)

  (set (make-local-variable 'ruby-symbol-chars)
       "a-zA-Z0-9_-")
  (set (make-local-variable 'ruby-symbol-re)
       (concat "[" ruby-symbol-chars "]"))

  (set-syntax-table hyphen-ruby-mode-syntax-table)
  (setq mode-name "Hyphen-Ruby")
  (setq major-mode 'hyphen-ruby-mode)
  (run-hooks 'hyphen-ruby-mode-hook))

(defvar hyphen-ruby-mode-syntax-table
  (let ((table (copy-syntax-table ruby-mode-syntax-table)))
    (modify-syntax-entry ?- "_" table)
    table))

(defvar hyphen-ruby-font-lock-syntax-table
  (let ((table (copy-syntax-table ruby-font-lock-syntax-table)))
    (modify-syntax-entry ?- "w" table)
    table))

(defvar hyphen-ruby-font-lock-keywords
  (copy-sequence ruby-font-lock-keywords))

(when (and (featurep 'font-lock) (not (featurep 'xemacs)))
  (add-hook 'hyphen-ruby-mode-hook
            (lambda ()
              (set (make-local-variable 'font-lock-syntax-table)
                   hyphen-ruby-font-lock-syntax-table)
              (set (make-local-variable 'font-lock-defaults)
                   '((hyphen-ruby-font-lock-keywords) nil nil))
              (set (make-local-variable 'font-lock-keywords)
                   hyphen-ruby-font-lock-keywords))))

(provide 'hyphen-ruby)
(provide 'hyphen-ruby-mode)
;;; hyphen-ruby-mode.el ends here.
