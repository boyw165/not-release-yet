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
;; Add the following to your .emacs file:
;; (require 'hl-anything)
;;
;; Enable parenethese highlighting.
;; (hl-paren-mode 1)
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Change Log:
;;
;; 2014-05-25 (0.0.4)
;;    Support searching thing. The thing might be a symbol text or a selection text.
;;
;; 2014-05-20 (0.0.3)
;;    Support one inward parentheses highlight.
;;
;; 2014-05-19 (0.0.2)
;;    Support multiple outward parentheses highlight.
;;
;; 2014-05-16 (0.0.1)
;;    Initial release, fork from http://nschum.de/src/emacs/highlight-parentheses.

(require 'thingatpt)
(eval-when-compile (require 'cl))

(defgroup hl-anything-group nil
  "Highlight anything."
  :tag "hl-anything"
  :group 'faces
  :group 'matching)

;; Parentheses =================================================================

(defun hl--paren-custom-set (symbol value)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (set symbol value)
      (when hl-paren-mode
        (hl-paren-mode -1)
        (hl-paren-mode 1)))))

(defcustom hl-outward-paren-fg-colors nil
  "List of colors for the highlighted parentheses. The list starts with the the inside parentheses and moves outwards."
  :type '(repeat color)
  :initialize 'custom-initialize-default
  :set 'hl--paren-custom-set
  :group 'hl-anything-group)

(defcustom hl-outward-paren-bg-colors '("cyan" "yellow")
  "List of colors for the background highlighted parentheses. The list starts with the the inside parentheses and moves outwards."
  :type '(repeat color)
  :initialize 'custom-initialize-default
  :set 'hl--paren-custom-set
  :group 'hl-anything-group)

(defcustom hl-inward-paren-fg-colors nil
  "List of colors for the highlighted parentheses. The list starts with the the inside parentheses and moves outwards."
  :type '(repeat color)
  :initialize 'custom-initialize-default
  :set 'hl--paren-custom-set
  :group 'hl-anything-group)

(defcustom hl-inward-paren-bg-colors '("hot pink")
  "List of colors for the background highlighted parentheses. The list starts with the the inside parentheses and moves outwards."
  :type '(repeat color)
  :initialize 'custom-initialize-default
  :set 'hl--paren-custom-set
  :group 'hl-anything-group)

(defface hl-paren-face nil
  "Face used for highlighting parentheses."
  :group 'hl-anything-group)

(defvar hl--outward-paren-overlays nil
  "This buffers currently active overlays.")
(make-variable-buffer-local 'hl--outward-paren-overlays)

(defvar hl--inward-paren-overlays nil
  "This buffers currently active overlays.")
(make-variable-buffer-local 'hl--inward-paren-overlays)

(defvar hl--paren-last-point 0
  "The last point for which parentheses were highlighted. This is used to prevent analyzing the same context over and over.")
(make-variable-buffer-local 'hl--paren-last-point)

;;;###autoload
(define-minor-mode hl-paren-mode
  "Minor mode to highlight the surrounding parentheses."
  :lighter " hl-p"
  (hl--paren-destruct-all)
  (when hl-paren-mode
    (hl--paren-create-overlays)
    (add-hook 'post-command-hook 'hl--paren-update nil t)
    (add-hook 'change-major-mode-hook 'hl--paren-destruct-all nil t)))

(defun hl--paren-create-overlays ()
  ;; outward overlays.
  (let ((fg hl-outward-paren-fg-colors)
        (bg hl-outward-paren-bg-colors)
        attributes)
    (while (or fg bg)
      (setq attributes (face-attr-construct 'hl-paren-face))
      (when (car fg)
        (setq attributes (plist-put attributes :foreground (car fg))))
      (pop fg)
      (when (car bg)
        (setq attributes (plist-put attributes :background (car bg))))
      (pop bg)

      ;; Make pair overlays for every attribute.
      (dotimes (i 2)
        (push (make-overlay 0 0) hl--outward-paren-overlays)
        (overlay-put (car hl--outward-paren-overlays) 'face attributes)))
    (setq hl--outward-paren-overlays (nreverse hl--outward-paren-overlays)))
  ;; inward overlays.
  (let ((fg hl-inward-paren-fg-colors)
        (bg hl-inward-paren-bg-colors)
        attributes)
    (while (or fg bg)
      (setq attributes (face-attr-construct 'hl-paren-face))
      (when (car fg)
        (setq attributes (plist-put attributes :foreground (car fg))))
      (pop fg)
      (when (car bg)
        (setq attributes (plist-put attributes :background (car bg))))
      (pop bg))

    ;; Make pair overlays for every attribute.
    (dotimes (i 2)
      (push (make-overlay 0 0) hl--inward-paren-overlays)
      (overlay-put (car hl--inward-paren-overlays) 'face attributes))))

(defun hl--paren-update ()
  "Highlight the parentheses around point."
  (unless (= (point) hl--paren-last-point)
    ;; Outward overlays.
    (setq hl--paren-last-point (point))
    (let ((overlays hl--outward-paren-overlays)
          (pos (point))
          pos1 pos2)
      (save-excursion
        (condition-case err
            (while (and (setq pos1 (cadr (syntax-ppss pos1)))
                        (cdr overlays))
              (move-overlay (pop overlays) pos1 (1+ pos1))
              (when (setq pos2 (scan-sexps pos1 1))
                (move-overlay (pop overlays) (1- pos2) pos2)))
          (error nil)))
      ;; Hide unused overlays.
      (dolist (ov overlays)
        (move-overlay ov 1 1)))

    ;; Inward overlays.
    (let ((overlays hl--inward-paren-overlays)
          (pos1 (point))
          pos2)
      (save-excursion
        (condition-case err
            (cond
             ((and (or (looking-back ")")
                       (looking-back "]")))
              ;; TODO: skip comment.
              (move-overlay (pop overlays) pos1 (1- pos1))
              (setq pos2 (scan-sexps pos1 -1))
              (move-overlay (pop overlays) pos2 (1+ pos2)))
             ((and (or (looking-at "(")
                       (looking-at "[")))
              ;; TODO: skip comment.
              (move-overlay (pop overlays) pos1 (1+ pos1))
              (setq pos2 (scan-sexps pos1 1))
              (move-overlay (pop overlays) pos2 (1- pos2))))
          (error nil)))
      ;; Hide unused overlays.
      (dolist (ov overlays)
        (move-overlay ov 1 1)))))

(defun hl--paren-destruct-all ()
  (mapc 'delete-overlay hl--outward-paren-overlays)
  (mapc 'delete-overlay hl--inward-paren-overlays)
  (kill-local-variable 'hl--outward-paren-overlays)
  (kill-local-variable 'hl--inward-paren-overlays)
  (kill-local-variable 'hl--paren-last-point)
  (remove-hook 'post-command-hook 'hl--paren-update t)
  (remove-hook 'post-command-hook 'hl--paren-destruct-all t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Highlight things ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;###autoload
(defun hl-highlight-thingatpt ()
  "Toggle highlighting of the thing at point."
  (interactive)
  (unless hl-highlight-mode
    (hl-highlight-mode 1))
  ;; TODO:
  )

;;;###autoload
(defun hl-highlight-thingatpt-local ()
  "Toggle highlighting of the thing at point."
  (interactive)
  (unless hl-highlight-mode
    (hl-highlight-mode 1))
  (let* ((thing (hl-thingatpt))
         (str (car thing)))
    (when thing
      (if (assoc str hl-things-local)
          (hl-unhighlight str t)
        (hl-highlight str t)))))

;;;###autoload
(defun hl-unhighlight-all-local ()
  "Remove all the highlights in buffer."
  (interactive)
  (dolist (thing hl-things-local)
    (hl-unhighlight (car thing) t))
  (setq hl-index-local 0))

;;;###autoload
(define-minor-mode hl-highlight-mode
  "Provide convenient menu items and tool-bar items for project feature."
  :lighter " Highlight"
  :global t
  (if hl-highlight-mode
      (progn
        (add-hook 'pre-command-hook 'hl-highlight-pre-command t nil)
        (add-hook 'post-command-hook 'hl-highlight-post-command t nil))
    (remove-hook 'pre-command-hook 'hl-highlight-pre-command nil)
    (remove-hook 'post-command-hook 'hl-highlight-post-command nil)))

(defcustom hl-fg-colors '("snow"
                          "snow"
                          "black"
                          "black"
                          "snow"
                          "snow"
                          "snow")
  "The foreground colors for `hl-highlight-thingatpt'."
  :type '(repeat color)
  :tag "Highlight Foreground Colors"
  :group 'hl-anything-group)

(defcustom hl-bg-colors '("orange red"
                          "Orange"
                          "gold"
                          "green1"
                          "DeepSkyBlue1"
                          "dark blue"
                          "blue violet")
  "The background colors for `hl-highlight-thingatpt'."
  :type '(repeat color)
  :tag "Highlight Background Colors"
  :group 'hl-anything-group)

(defcustom hl-before-find-thing-hook nil
  "Hook for doing something before `hl--thing-find' do the searching.
This hook has one argument, (REGEXP_STRING BEG END).
Maybe you'll need it for history and navigation feature."
  :type '(repeat function)
  :group 'hl-anything-group)

(defcustom hl-after-find-thing-hook nil
  "Hook for doing something after `hl--thing-find' do the searching.
This hook has one argument, (REGEXP_STRING BEG END).
Maybe you'll need it for history and navigation feature."
  :type '(repeat function)
  :group 'hl-anything-group)

(defvar hl-index 0)

(defvar hl-things nil
  "A things list. The list stores things to be highlighted globally in the 
buffer. The things's format:
  ((REGEXP . FACESPEC) ...)")

(defvar hl-index-local 0)
(make-variable-buffer-local 'hl-index-local)

(defvar hl-things-local nil
  "A things list. The list only stores things to be highlighted locally in the 
buffer. The things's format:
  ((REGEXP . FACESPEC) ...)")
(make-variable-buffer-local 'hl-things-local)

(defvar hl-overlays-local nil)
(make-variable-buffer-local 'hl-overlays-local)

(defvar hl-overlay-bound 0)

(defvar hl-timer nil)

(defconst hl-idle-delay 0.1)

(defun hl-thingatpt ()
  "Return a list, (REGEXP_STRING BEG END), on which the point is or just string
 of selection."
  ;; TODO: Use the highlight if point is on it.
  (let ((bound (if mark-active
                   (cons (region-beginning) (region-end))
                 (hl-bounds-of-thingatpt))))
    (when bound
      ;; TODO: Improve regexp translation in order to support multiple lines.
      (let ((text (regexp-quote
                   (buffer-substring-no-properties (car bound) (cdr bound)))))
        ;; Replace space as "\\s-+"
        (setq text (replace-regexp-in-string "\\s-+" "\\\\s-+" text))
        (list text (car bound) (cdr bound))))))

(defun hl-bounds-of-thingatpt ()
  (let ((face (get-text-property (point) 'face)))
    (if (or (facep face)
            (null face))
        (bounds-of-thing-at-point 'symbol)
      (hl-bounds-of-highlight))))

(defun hl-bounds-of-highlight ()
  (let* ((face (get-text-property (point) 'face))
         (fg (assoc 'foreground-color face))
         (bg (assoc 'background-color face))
         beg end)
    ;; Find beginning.
    (save-excursion
      (while (and (listp face)
                  (equal fg (assoc 'foreground-color face))
                  (equal bg (assoc 'background-color face)))
        (setq beg (point))
        (backward-char)
        (setq face (get-text-property (point) 'face))))
    (setq face (get-text-property (point) 'face))
    ;; Find end.
    (save-excursion
      (while (and (listp face)
                  (equal fg (assoc 'foreground-color face))
                  (equal bg (assoc 'background-color face)))
        (forward-char)
        (setq end (point))
        (setq face (get-text-property (point) 'face))))
    (when (and beg end)
      (cons beg end))))

(defun hl-highlight (thing &optional local)
  (let* ((index (if local
                    hl-index-local
                  hl-index))
         (mode (if local
                   nil
                 major-mode))
         (fg (nth index hl-fg-colors))
         (bg (nth index hl-bg-colors))
         (max (max (length hl-fg-colors)
                   (length hl-bg-colors)))
         (next-index (1+ index))
         facespec)
    (when fg
      (setq facespec (append facespec `((foreground-color . ,fg)))))
    (when bg
      (setq facespec (append facespec `((background-color . ,bg)))))
    (font-lock-add-keywords mode `((,thing 0 ',facespec prepend)) 'append)
    (if local
        (progn
          (font-lock-fontify-buffer)
          (push (cons thing facespec) hl-things-local)
          (setq hl-index-local (if (>= next-index max) 0 next-index)))
      (font-lock-refresh-defaults)
      (push (cons thing facespec) hl-things)
      (setq hl-index (if (>= next-index max) 0 next-index)))))

(defun hl-unhighlight (thing &optional local)
  (let* ((mode (if local
                   nil
                 major-mode))
         ;; (real-thing (car thing))
         (keyword (assoc thing (if (eq t (car font-lock-keywords))
                                   (cadr font-lock-keywords)
                                 font-lock-keywords))))
    (font-lock-remove-keywords mode `(,keyword))
    (if local
        (progn
          (font-lock-fontify-buffer)
          (setq hl-things-local (delete (assoc thing hl-things-local)
                                        hl-things-local)))
      (font-lock-refresh-defaults)
      (setq hl-things (delete (assoc thing hl-things)
                              hl-things)))))

(defun hl-highlight-pre-command ()
  ;; (when hl-timer
  ;;   (cancel-timer hl-timer)
  ;;   (setq hl-timer nil))
  ;; (hl-remove-highlight-overlays)
  )

(defun hl-highlight-post-command ()
  ;; (when (hl-is-idle-begin)
  ;;   (setq hl-timer (run-with-timer hl-idle-delay nil
  ;;                                  'hl-add-highlight-overlays)))
  )

(defun hl-is-idle-begin ()
  (not (or (active-minibuffer-window))))

;; (setq test (make-overlay 100 120))
;; (overlay-put test 'face `((background-color . "gold")))
(defun hl-add-highlight-overlays ()
  (let ((things (append hl-things hl-things-local)))
    (dolist (thing things)
      (let ((beg (line-beginning-position))
            (end (line-end-position)))
        (save-excursion
          (goto-char beg)
          (while (re-search-forward thing end t)
            ))))))

(defun hl-remove-highlight-overlays ()
  (when (or hl-things hl-things-local)
    (let ((min (car hl-overlays-local))
          (max (cdr hl-overlays-local)))
      (when (and (>= (point) min)
                 (<= (point) max))
        ))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;###autoload
(defun hl-find-thing-forwardly ()
  "Find thing forwardly and jump to it."
  (interactive)
  (hl-find-thing 1))

;;;###autoload
(defun hl-find-thing-backwardly ()
  "Find thing backwardly and jump to it."
  (interactive)
  (hl-find-thing -1))

(defun hl-find-thing (step)
  (let* ((thing (hl-thingatpt))
         (match (nth 0 thing))
         (beg (nth 1 thing))
         (end (nth 2 thing))
         (case-fold-search t))
    (when thing
      ;; Hook before searching.
      (run-hook-with-args hl-before-find-thing-hook thing)
      (setq mark-active nil)
      (goto-char (nth (if (> step 0)
                          ;; Move to end.
                          2
                        ;; Move to beginning.
                        1) thing))
      (if (re-search-forward match nil t step)
          (progn
            (set-marker (mark-marker) (match-beginning 0))
            (goto-char (match-end 0)))
        (set-marker (mark-marker) beg)
        (goto-char end))
      (setq mark-active t)
      ;; Hook after searching.
      (run-hook-with-args hl-after-find-thing-hook thing))))

(provide 'hl-anything)
