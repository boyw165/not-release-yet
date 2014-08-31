;; Copyright (C) 2014
;;
;; Author: BoyW165
;; Version: 0.0.1
;; Compatibility: GNU Emacs 22.x, GNU Emacs 23.x, GNU Emacs 24.x
;;
;; This file is NOT part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;
;;; Commentary:
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Change Log:
;;
;; 2014-08-01 (0.0.1)
;;    Initial release.

(defcustom sos-nav-mode-hook '()
  "Hook run when entering `prj-grep-mode' mode."
  :type 'hook
  :group 'sos-group)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun sos-nav-kill-local-variables ()
  (mapc 'kill-local-variable '(mode-line-format)))

;; (self-insert-command)
(defun sos-nav-mode-line ()
  nil)

;;;###autoload
(define-minor-mode sos-nav-mode
  "Minor mode for *Reference* buffers."
  :lighter " SOS:Navigation"
  :group 'sos-group
  (if sos-nav-mode
      (progn
        (setq mode-line-format (sos-nav-mode-line)))
    (sos-nav-kill-local-variables)))

(provide 'sos-nav)
