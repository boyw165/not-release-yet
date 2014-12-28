;;; history.el --- Smart navigation history engine.
;;
;; Copyright (C) 2014
;;
;; Author: boyw165
;; Version: 20141204.1100
;; Package-Requires: ((emacs "24.3"))
;; Compatibility: GNU Emacs 24.3+
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
;; `pop-global-mark' let you go back to where you were but also discard them.
;;
;; TODO:
;; -----
;; n/a
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Change Log:
;;
;; 2014-12-28
;; * Support `his-ignore-buffer-names' to ignore some buffer with specific names.
;; * Enhance visualization of `his-show-history'.
;;
;; 2014-06-01
;; * Initial release.
;;
;;; Code:

;; GNU Library.
(require 'thingatpt)

(defgroup history nil
  "A lightweight history utility.")

(defcustom his-history-max 16
  "The maximum lenght of history."
  :type 'integer
  :group 'history)

(defcustom his-history-savepath "~/.emacs.d/.history"
  "Path of cached history."
  :type 'string
  :group 'history)

(defcustom his-ignore-buffer-names '("\*.*\*")
  "Ths REGEXP list for matched ignore buffer names."
  :type '(repeat regexp)
  :group 'history)

(defvar his-histories nil
  "The history database. see `his-add-history' for details.")

(defvar his-index 0)

(defun his-same-line? (pos1 pos2)
  (let ((line-pos1 (save-excursion
                     (goto-char pos1)
                     (beginning-of-line)
                     (point)))
        (line-pos2 (save-excursion
                     (goto-char pos2)
                     (beginning-of-line)
                     (point))))
    (= line-pos1 line-pos2)))

(defun his-add-history-internal (history)
  ;; Discard old histories.
  (and his-histories (> his-index 0)
       (let ((current (nthcdr his-index his-histories)))
         (setq his-histories (cdr current))))
  ;; Add new history.
  (push history his-histories)
  (setq his-index 0)
  ;; Keep total amount of history is less than `his-history-max'.
  (and (> (length his-histories) his-history-max)
       (setcdr (nthcdr (1- his-history-max) his-histories) nil)))

(defun his-remove-invalid-history ()
  "Go through the histories and check each buffer's validness."
  (dolist (history his-histories)
    (let* ((marker (plist-get history :marker))
           (buffer (marker-buffer marker))
           (pos (marker-position marker))
           (symbol (plist-get history :symbol)))
      (if (buffer-live-p buffer)
          ;; If need to compare thing at point with history.
          (when symbol
            (with-current-buffer buffer
              (save-excursion
                (goto-char pos)
                (unless (equal symbol (thing-at-point 'symbol t))
                  ;; Remove it if thing at point doesn't match history.
                  (setq his-histories (delq history his-histories))))))
        ;; Remove it if its buffer was killed.
        (setq his-histories (delq history his-histories)))))
  ;; Update index if necessary.
  (when (> his-index (length his-histories))
    (setq his-index (1- (length his-histories)))))

(defun his-move-history (step)
  (setq his-index (+ his-index step))
  (cond
   ((>= his-index (length his-histories))
    (setq his-index (1- (length his-histories))))
   ((< his-index 0)
    (setq his-index 0))))

(defun his-use-current-history ()
  (if (= (length his-histories) 0)
      (message "[History] no history!")
    (let* ((history (nth his-index his-histories))
           (marker (plist-get history :marker))
           (buffer (marker-buffer marker))
           (pos (marker-position marker)))
      ;; Switch to buffer.
      (switch-to-buffer buffer)
      ;; Update point.
      (goto-char pos))
    (message "[History] navigate to %s/%s."
             (if (> (length his-histories) 0)
                 (- (length his-histories) his-index) 0)
             (length his-histories))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public Functions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;###autoload
(defun his-add-history (&optional is-thing?)
  "Add current position into the database, which is `global-mark-ring'. If 
IS-THING? is t, it will cache the symbol string at point (if any) and use it as 
a comparison in checking algorithm when navigating to it. If they are not matched, 
the history will be deleted immediately."
  (interactive)
  (let (history
        (thing (thing-at-point 'symbol t)))
    ;; Create history.
    (setq history (plist-put history :marker (copy-marker (point) t)))
    ;; Cache the symbol string if necessary.q
    (and is-thing? thing
         (setq history (plist-put history :symbol thing)))
    ;; Add to databse.
    (catch 'ignore
      (dolist (ignore his-ignore-buffer-names)
        (when (string-match ignore (buffer-name))
          (throw 'ignore (message "ignore"))))
      (his-add-history-internal history))))

;;;###autoload
(defun his-show-history ()
  "Show histories in a pretty way."
  (interactive)
  (his-remove-invalid-history)
  (message "[History] index/total = %s/%s\n[History] history = %s"
           (if (> (length his-histories) 0)
               (1+ his-index) 0)
           (length his-histories)
           his-histories))

;;;###autoload
(defun his-goto-history ()
  (interactive)
  )

;;;###autoload
(defun his-discard-histories ()
  "Discard all the histories."
  (interactive)
  (setq his-index 0
        his-histories nil))

;;;###autoload
(defun his-prev-history ()
  "Navigate to previous history."
  (interactive)
  (when his-histories
    (his-remove-invalid-history)
    (let* ((history (nth his-index his-histories))
	   (marker (plist-get history :marker))
           (buffer (marker-buffer marker))
           (pos (marker-position marker)))
      ;; If point is far away from current history, use current history.
      ;; If point is close from current history, use next/previous history.
      (when (and (eq buffer (current-buffer))
                 (his-same-line? (point) pos))
        (his-move-history 1))))
  (his-use-current-history))

;;;###autoload
(defun his-next-history ()
  "Navigate to next history."
  (interactive)
  (when his-histories
    (his-remove-invalid-history)
    (let* ((history (nth his-index his-histories))
	   (marker (plist-get history :marker))
           (buffer (marker-buffer marker))
           (pos (marker-position marker)))
      ;; If point is far away from current history, use current history.
      ;; If point is close from current history, use next/previous history.
      (when (and (eq buffer (current-buffer))
                 (his-same-line? (point) pos))
        (his-move-history -1))))
  (his-use-current-history))

;;;###autoload
(define-minor-mode history-mode
  "Add menus, toolbar buttons and more."
  :lighter " history"
  :global t
  (if history-mode
      (progn
        )
    ))

;;;###autoload
(defun his-add-menu-and-toolbar-item ()
  ;; menu bar
  (define-key (default-value 'global-map) [menu-bar edit separator-history]
    '(menu-item "--"))

  ;; .------------------.
  ;; | Next History     |
  ;; | Previous History |
  ;; | History....-----------------.
  ;; |           | Set History     |
  ;; ~ ~ ~ ~ ~ ~ | Show History    |
  ;;             | Discard History |
  ;;             '-----------------'
  (define-key (default-value 'global-map) [menu-bar edit history-more]
    (cons "History..." (make-sparse-keymap "History Miscellaneous Function...")))
  (define-key (default-value 'global-map) [menu-bar edit history-more discard-history]
    '(menu-item "Discard History" his-discard-histories
		:enable (> (length his-histories) 0)
		:help "Discard all the history"))
  (define-key (default-value 'global-map) [menu-bar edit history-more show-history]
    '(menu-item "List History" his-show-history
		:help "List history in a buffer"))
  (define-key (default-value 'global-map) [menu-bar edit history-more set-history]
    '(menu-item "Set History" his-add-history
		:help "Add a history refer to current buffer and point"))

  ;; .------------------.
  ;; | Next History     |
  ;; | Previous History |
  ;; | History...       |
  ;; |                  |
  ;; ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
  ;; (define-key global-map [menu-bar edit next-history]
  ;;   '("Next History" . his-next-history))
  (define-key (default-value 'global-map) [menu-bar edit next-history]
    '(menu-item "Next History" his-next-history
		:enable (> (length his-histories) 0)
		:help "Go to next history"))
  (define-key (default-value 'global-map) [menu-bar edit previous-history]
    '(menu-item "Previous History" his-prev-history
		:enable (> (length his-histories) 0)
		:help "Go to previous history"))

  ;; tool bar
  (when tool-bar-mode
    (define-key (default-value 'tool-bar-map) [separator-history]
      '("--"))
    (define-key (default-value 'tool-bar-map) [set-history]
      '(menu-item "Set History" his-add-history
                  :image (find-image '((:type xpm :file "set-history.xpm")))
                  :help "Add a history refer to current buffer and point"))
    (define-key (default-value 'tool-bar-map) [next-history]
      '(menu-item "Next History" his-next-history
                  :image (find-image '((:type xpm :file "next-history.xpm")))
                  :enable (> (length his-histories) 0)
                  :help "Go to next history"))
    (define-key (default-value 'tool-bar-map) [previous-history]
      '(menu-item "Previous History" his-prev-history
                  :image (find-image '((:type xpm :file "prev-history.xpm")))
                  :enable (> (length his-histories) 0)
                  :help "Go to previous history"))))

;; Automatically add menu items of this feature.
(his-add-menu-and-toolbar-item)

(provide 'history)
;;; history.el ends here
