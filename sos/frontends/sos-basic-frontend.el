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
;; This is a framework that refers to the point and show useful information.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Change Log:
;;
;; 2014-10-01 (0.0.1)
;;    Initial release.

(defvar sos-definition-buffer nil)

(defvar sos-definition-window nil)

(defvar sos-definition-window-height 0)

(defvar sos-file-name nil
  "Cache file name for `sos-navigation-mode'.")

(defvar sos-file-linum nil
  "Cache line number for `sos-navigation-mode'.")

(defvar sos-file-keyword nil
  "Cache keyword string for `sos-navigation-mode'.")

(defmacro sos-with-definition-buffer (&rest body)
  "Get definition buffer and window ready then interpret the `body'."
  (declare (indent 0) (debug t))
  `(progn
     (unless sos-definition-buffer
       (setq sos-definition-buffer (get-buffer-create "*Definition*")))
     (unless (window-live-p sos-definition-window)
       (let* ((win (cond
                    ;; Only one window ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                    ((window-live-p (frame-root-window))
                     (selected-window))
                    ;; Default ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                    (t (selected-window))))
              (height (or (and (> sos-definition-window-height 0)
                               (- 0 sos-definition-window-height))
                          (and win
                               (/ (window-height win) -3)))))
         (and win height
              (setq sos-definition-window (split-window win height 'below)))))
     ;; Bind definition buffer to definition window.
     (set-window-buffer sos-definition-window sos-definition-buffer t)
     (with-selected-window sos-definition-window
       (with-current-buffer sos-definition-buffer
         ;; Disable minor modes (read-write enabled, ...etc) and update buffer.
         (sos-navigation-mode -1)
         ;; Overlays
         (unless (and sos-hl-overlay
                      (buffer-live-p (overlay-buffer sos-hl-overlay)))
           (setq sos-hl-overlay (make-overlay 1 1)))
         (overlay-put sos-hl-overlay 'face sos-hl-face)
         ;; `body' >>>
         (progn ,@body)
         ;; Enable minor modes (read-only, ...etc).
         (sos-navigation-mode 1)))))

(defun sos-toggle-definition-buffer&window (toggle)
  "Display or hide the `sos-definition-buffer' and `sos-definition-window'."
  (let ((enabled (or (and (booleanp toggle) toggle)
                     (and (numberp toggle)
                          (> toggle 0)))))
    (if enabled
        (sos-with-definition-buffer)
      (when (windowp sos-definition-window)
        (delete-window sos-definition-window))
      (when (bufferp sos-definition-buffer)
        (kill-buffer sos-definition-buffer))
      (setq sos-definition-buffer nil
            sos-definition-window nil
            sos-hl-overlay nil))))

;;;###autoload
(defun sos-definition-buffer-frontend (command)
  (case command
    (:show
     (sos-toggle-definition-buffer&window 1)
     ;; TODO: multiple candidates `sos-is-single-candidate'.
     (if (sos-is-single-candidate)
         (let* ((candidate (car sos-candidates))
                (file (plist-get candidate :file))
                (linum (plist-get candidate :linum))
                (hl-word (plist-get candidate :hl-word)))
           (when (file-exists-p file)
             (sos-with-definition-buffer
               (insert-file-contents file nil nil nil t)
               ;; Set them for `sos-nav-mode'.
               (setq sos-file-name file
                     sos-file-linum linum
                     sos-file-keyword hl-word)
               ;; Find a appropriate major-mode for it.
               (dolist (mode auto-mode-alist)
                 (and (not (null (cdr mode)))
                      (string-match (car mode) file)
                      (funcall (cdr mode))))
               (and (featurep 'hl-line)
                    (hl-line-unhighlight))
               ;; Move point and recenter.
               (and (integerp linum)
                    (goto-char (point-min))
                    (forward-line (- linum 1)))
               (recenter 3)
               ;; Highlight word or line.
               (move-overlay sos-hl-overlay 1 1)
               (or (and (stringp hl-word) (> (length hl-word) 0)
                        (search-forward hl-word (line-end-position) t)
                        (move-overlay sos-hl-overlay (- (point) (length hl-word)) (point)))
                   (and hl-line
                        (move-overlay sos-hl-overlay (line-beginning-position) (+ 1 (line-end-position))))))))))
    (:hide (sos-toggle-definition-buffer&window -1))
    (:update
     (unless sos-definition-buffer
       (sos-definition-buffer-frontend :show)))))

;;;###autoload
(defun sos-tips-frontend (command)
  (case command
    (:show
     (when (stringp sos-tips)
       ;; TODO: draw a overlay.
       ;; (message "%s" sos-tips)
       ))
    (:hide nil)
    (:update nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defcustom sos-navigation-mode-hook '()
  "Hook run when entering `prj-grep-mode' mode."
  :type 'hook
  :group 'sos-group)

;; TODO: keymap.
(defvar sos-navigation-map nil)
(defvar sos-nav-file-map nil)
(defvar sos-nav-file-linum-map nil)

;; Sample:
;; (defvar mode-line-position
;;   `((-3 ,(propertize
;; 	  "%p"
;; 	  'local-map mode-line-column-line-number-mode-map
;; 	  'mouse-face 'mode-line-highlight
;; 	  ;; XXX needs better description
;; 	  'help-echo "Size indication mode"))
;;     (size-indication-mode
;;      (8 ,(propertize
;; 	  " of %I"
;; 	  'local-map mode-line-column-line-number-mode-map
;; 	  'mouse-face 'mode-line-highlight
;; 	  ;; XXX needs better description
;; 	  'help-echo "Size indication mode")))
;;     (line-number-mode
;;      ((column-number-mode
;;        (10 ,(propertize
;; 	     " (%l,%c)"
;; 	     'local-map mode-line-column-line-number-mode-map
;; 	     'mouse-face 'mode-line-highlight
;; 	     'help-echo "Line number and Column number"))
;;        (6 ,(propertize
;; 	    " L%l"
;; 	    'local-map mode-line-column-line-number-mode-map
;; 	    'mouse-face 'mode-line-highlight
;; 	    'help-echo "Line Number"))))
;;      ((column-number-mode
;;        (5 ,(propertize
;; 	    " C%c"
;; 	    'local-map mode-line-column-line-number-mode-map
;; 	    'mouse-face 'mode-line-highlight
;; 	    'help-echo "Column number")))))))

(defun sos-navigation-mode-line ()
  `(,(propertize " %b "
                 'face 'mode-line-buffer-id)
    (:eval (and sos-file-name
                (concat "| file:" (propertize (abbreviate-file-name sos-file-name)
                                              'local-map sos-nav-file-map
                                              'face 'link
                                              'mouse-face 'mode-line-highlight)
                        (and sos-file-linum
                             (concat ", line:" (propertize (format "%d" sos-file-linum)
                                                           'local-map sos-nav-file-linum-map
                                                           'face 'link
                                                           'mouse-face 'mode-line-highlight)))
                        ", function:(yet supported)")))))

;;;###autoload
(define-minor-mode sos-navigation-mode
  "Minor mode for *Definition* buffers."
  :lighter " SOS:Navigation"
  :group 'sos-group
  (if sos-navigation-mode
      (progn
        (setq mode-line-format (sos-navigation-mode-line)
              buffer-read-only t))
    (setq buffer-read-only nil
          sos-file-name nil
          sos-file-linum nil
          sos-file-keyword nil)
    (mapc 'kill-local-variable '(mode-line-format))))

(provide 'sos-basic-frontend)
