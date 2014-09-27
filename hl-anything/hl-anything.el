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
;; Toggle highlighting things at point:
;;   M-x hl-highlight-thingatpt-local
;;
;; Remove all highlights:
;;   M-x hl-unhighlight-all-local
;;
;; Enable parenethese highlighting:
;;   M-x hl-paren-mode
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Change Log:
;;
;; 2014-09-25 (0.0.5)
;;    1. Highlights won't be blocked behind the current line when `hl-line-mode'
;;       is enabled.
;;    2. Smartly select highlighted region.
;;    3. Highlight words across multiple lines.
;;
;; 2014-05-25 (0.0.4)
;;    Support searching thing. The regexp might be a symbol text or a selection text.
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Highlight things ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;###autoload
(defun hl-highlight-thingatpt ()
  "Toggle highlighting globally."
  (interactive)
  ;; TODO:
  )

;;;###autoload
(defun hl-highlight-thingatpt-local ()
  "Toggle highlighting locally in the current buffer."
  (interactive)
  (unless hl-highlight-mode
    (hl-highlight-mode 1))
  (let* ((thing (hl-thingatpt))
         (regexp (car thing)))
    (when thing
      (if (member regexp hl-things-local)
          (hl-unhighlight-internal regexp t)
        (hl-highlight-internal regexp t)))))

;;;###autoload
(defun hl-unhighlight-all-local ()
  "Remove all the highlights in buffer."
  (interactive)
  (dolist (regexp hl-things-local)
    (hl-unhighlight-internal regexp t))
  (setq hl-index-local 0))

;;;###autoload
(defun hl-highlight-line (linum &optional facespec)
  ;; TODO:
  )

;;;###autoload
(define-minor-mode hl-highlight-mode
  "Provide convenient menu items and tool-bar items for project feature."
  :lighter " Highlight"
  (if hl-highlight-mode
      (progn
        (add-hook 'pre-command-hook 'hl-remove-highlight-overlays t t)
        (add-hook 'post-command-hook 'hl-highlight-post-command t t))
    (remove-hook 'pre-command-hook 'hl-remove-highlight-overlays t)
    (remove-hook 'post-command-hook 'hl-highlight-post-command t)))

(defcustom hl-fg-colors '("snow"
                          "snow"
                          "black"
                          "black"
                          "snow"
                          "snow"
                          "snow"
                          "black"
                          "snow"
                          "snow")
  "The foreground colors for `hl-highlight-thingatpt'."
  :type '(repeat color)
  :tag "Highlight Foreground Colors"
  :group 'hl-anything-group)

(defcustom hl-bg-colors '("firebrick"
                          "Orange"
                          "gold"
                          "green1"
                          "DeepSkyBlue1"
                          "dark blue"
                          "blue violet"
                          "gray90"
                          "gray60"
                          "gray30")
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
  "A global things list. Format: ((REGEXP . FACESPEC) ...)")

(defvar hl-index-local 0)
(make-variable-buffer-local 'hl-index-local)

(defvar hl-things-local nil
  "A local things list. Format: (REGEXP1 REGEXP2 ...)")
(make-variable-buffer-local 'hl-things-local)

(defvar hl-overlays-local nil
  "Overlays for highlighted things. Prevent them to being hide by 
`hl-line-mode'.")
(make-variable-buffer-local 'hl-overlays-local)

(defvar hl-is-always-overlays-local nil
  "Force to create `hl-overlays-local' overlays.")
(make-variable-buffer-local 'hl-is-always-overlays-local)

(defun hl-thingatpt ()
  "Return a list, (REGEXP_STRING BEG END), on which the point is or just string
 of selection."
  (let ((bound (if mark-active
                   (cons (region-beginning) (region-end))
                 (hl-bounds-of-thingatpt))))
    (when bound
      (let ((text (regexp-quote
                   (buffer-substring-no-properties (car bound) (cdr bound)))))
        ;; Replace space as "\\s-+"
        (setq text (replace-regexp-in-string "\\s-+" "\\\\s-+" text))
        (list text (car bound) (cdr bound))))))

(defun hl-bounds-of-thingatpt ()
  (or (hl-bounds-of-highlight)
      (bounds-of-thing-at-point 'symbol)))

(defun hl-bounds-of-highlight ()
  "Return the start and end locations for the highlighted things at point.
Format: (START . END)"
  (let* ((face (get-text-property (point) 'face))
         org-fg org-bg
         beg end)
    (when (and (not (null face))
               (not (facep face)))
      (setq org-fg (assoc 'foreground-color face)
            org-bg (assoc 'background-color face))
      ;; Find beginning locations.
      (save-excursion
        (while (and (not (null face))
                    (not (facep face))
                    (equal org-fg (assoc 'foreground-color face))
                    (equal org-bg (assoc 'background-color face)))
          (setq beg (point))
          (backward-char)
          (setq face (get-text-property (point) 'face))))
      ;; Return to original point.
      (setq face (get-text-property (point) 'face))
      ;; Find end locations.
      (save-excursion
        (while (and (not (null face))
                    (not (facep face))
                    (equal org-fg (assoc 'foreground-color face))
                    (equal org-bg (assoc 'background-color face)))
          (forward-char)
          (setq end (point))
          (setq face (get-text-property (point) 'face))))
      (cons beg end))))

(defun hl-highlight-internal (regexp &optional local)
  (let* ((fg (nth hl-index-local hl-fg-colors))
         (bg (nth hl-index-local hl-bg-colors))
         (max (max (length hl-fg-colors)
                   (length hl-bg-colors)))
         (next-index (1+ hl-index-local))
         facespec)
    (push regexp hl-things-local)
    (setq hl-index-local (if (>= next-index max) 0 next-index))
    ;; Highlight.
    (when fg
      (setq facespec (append facespec `((foreground-color . ,fg)))))
    (when bg
      (setq facespec (append facespec `((background-color . ,bg)))))
    (font-lock-add-keywords nil `((,regexp 0 ',facespec prepend)) 'append)
    (font-lock-fontify-buffer)
    (hl-add-highlight-overlays regexp facespec)))

(defun hl-unhighlight-internal (regexp &optional local)
  (let* ((keyword (hl-is-font-lock-keywords regexp)))
    (setq hl-things-local (delete regexp hl-things-local))
    (hl-remove-highlight-overlays)
    ;; Unhighlight.
    (while (setq keyword (hl-is-font-lock-keywords regexp))
      (font-lock-remove-keywords nil `(,keyword)))
    (font-lock-fontify-buffer)
    (hl-remove-highlight-overlays)))

(defun hl-is-font-lock-keywords (regexp)
  (assoc regexp (if (eq t (car font-lock-keywords))
                    (cadr font-lock-keywords)
                  font-lock-keywords)))

(defun hl-highlight-post-command ()
  (when (hl-is-begin)
    (hl-add-highlight-overlays)))

(defun hl-is-begin ()
  (not (or (active-minibuffer-window)
           (memq this-command '(left-char
                                right-char)))))

(defmacro hl-with-highlights-at-current-line (&rest body)
  `(let ((end (line-end-position))
         bound)
     (save-excursion
       (goto-char (line-beginning-position))
       (while (<= (point) end)
         (if (setq bound (hl-bounds-of-highlight))
             ,@body
           (forward-char))))))

(defun hl-add-highlight-overlays (&optional regexp facespec)
  (when (or (and (featurep 'hl-line) hl-line-mode
                 (or hl-things hl-things-local))
            hl-is-always-overlays-local)
    (if (and regexp facespec)
        ;; If THING and FACESPEC is present, add overlays on the line.
        ;; It is a workaround:
        ;; It seems like the text properties are updated only after all the
        ;; `post-command-hook' were executed. So we have to manually insert
        ;; overlays when fontification is called at very 1st time.
        (save-excursion
          (let ((end (line-end-position)))
            (while (re-search-forward regexp end t)
              (let* ((match-beg (match-beginning 0))
                     (match-end (match-end 0))
                     (overlay (make-overlay match-beg match-end)))
                (overlay-put overlay 'face `(,facespec))
                (push overlay hl-overlays-local)))))
      (let ((end (line-end-position))
            bound)
        (save-excursion
          (goto-char (line-beginning-position))
          (while (<= (point) end)
            (if (setq bound (hl-bounds-of-highlight))
                (let* ((overlay (make-overlay (point) (cdr bound)))
                       (face (get-text-property (point) 'face))
                       (fg (assoc 'foreground-color face))
                       (bg (assoc 'background-color face)))
                  (overlay-put overlay 'face `(,fg ,bg))
                  (push overlay hl-overlays-local)
                  (goto-char (cdr bound)))
              (forward-char))))))))

(defun hl-remove-highlight-overlays ()
  (mapc 'delete-overlay hl-overlays-local)
  (setq hl-overlays-local nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;###autoload
(defun hl-find-thing-forwardly ()
  "Find regexp forwardly and jump to it."
  (interactive)
  (hl-find-thing 1))

;;;###autoload
(defun hl-find-thing-backwardly ()
  "Find regexp backwardly and jump to it."
  (interactive)
  (hl-find-thing -1))

(defun hl-find-thing (step)
  (let* ((regexp (hl-thingatpt))
         (match (nth 0 regexp))
         (beg (nth 1 regexp))
         (end (nth 2 regexp))
         (case-fold-search t))
    (when regexp
      ;; Hook before searching.
      (run-hook-with-args hl-before-find-thing-hook regexp)
      (setq mark-active nil)
      (goto-char (nth (if (> step 0)
                          ;; Move to end.
                          2
                        ;; Move to beginning.
                        1) regexp))
      (if (re-search-forward match nil t step)
          (progn
            (set-marker (mark-marker) (match-beginning 0))
            (goto-char (match-end 0)))
        (set-marker (mark-marker) beg)
        (goto-char end))
      (setq mark-active t)
      ;; Hook after searching.
      (run-hook-with-args hl-after-find-thing-hook regexp))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Parentheses ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun hl-paren-custom-set (symbol value)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (set symbol value)
      (when hl-paren-mode
        (hl-paren-mode -1)
        (hl-paren-mode 1)))))

(defcustom hl-outward-paren-fg-colors '("black"
                                        "black")
  "List of colors for the highlighted parentheses. The list starts with the the inside parentheses and moves outwards."
  :type '(repeat color)
  :initialize 'custom-initialize-default
  :set 'hl-paren-custom-set
  :group 'hl-anything-group)

(defcustom hl-outward-paren-bg-colors '("cyan"
                                        "gold")
  "List of colors for the background highlighted parentheses. The list starts with the the inside parentheses and moves outwards."
  :type '(repeat color)
  :initialize 'custom-initialize-default
  :set 'hl-paren-custom-set
  :group 'hl-anything-group)

(defcustom hl-inward-paren-fg-color "snow"
  "List of colors for the background highlighted parentheses. The list starts with the the inside parentheses and moves outwards."
  :type 'color
  :initialize 'custom-initialize-default
  :set 'hl-paren-custom-set
  :group 'hl-anything-group)

(defcustom hl-inward-paren-bg-color "magenta1"
  "List of colors for the background highlighted parentheses. The list starts with the the inside parentheses and moves outwards."
  :type 'color
  :initialize 'custom-initialize-default
  :set 'hl-paren-custom-set
  :group 'hl-anything-group)

(defface hl-paren-face nil
  "Face used for highlighting parentheses."
  :group 'hl-anything-group)

(defvar hl-paren-timer nil)

(defvar hl-outward-parens nil
  "This buffers currently active overlays.")
(make-variable-buffer-local 'hl-outward-parens)

(defvar hl-inward-parens nil
  "This buffers currently active overlays.")
(make-variable-buffer-local 'hl-inward-parens)

;;;###autoload
(define-minor-mode hl-paren-mode
  "Minor mode to highlight the surrounding parentheses."
  :lighter " hl-p"
  (if hl-paren-mode
      (progn
        (add-hook 'pre-command-hook 'hl-remove-parens nil t)
        (add-hook 'post-command-hook 'hl-paren-idle-begin nil t))
    (remove-hook 'pre-command-hook 'hl-remove-parens t)
    (remove-hook 'post-command-hook 'hl-paren-idle-begin t)))

(defun hl-paren-idle-begin ()
  (when (hl-paren-is-begin)
    (setq hl-paren-timer (run-with-timer 0 nil 'hl-create-parens))))

(defun hl-paren-is-begin ()
  (not (or (active-minibuffer-window))))

(defun hl-create-parens ()
  "Highlight the parentheses around point."
  (hl-create-parens-internal)
  ;; Outward overlays.
  (let ((overlays hl-outward-parens))
    (save-excursion
      (condition-case err
          (while overlays
            (up-list -1)
            (move-overlay (pop overlays) (point) (1+ (point)))
            (forward-sexp)
            (move-overlay (pop overlays) (1- (point)) (point)))
        (error nil)))
    ;; Hide unused overlays.
    (dolist (overlay overlays)
      (move-overlay overlay 1 1)))
  ;; Inward overlays.
  (unless (memq (get-text-property (point) 'face)
                '(font-lock-comment-face
                  font-lock-string-face))
    (let ((overlays hl-inward-parens))
      (save-excursion
        (condition-case err
            (cond
             ;; Open parenthesis ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
             ((eq ?\( (char-syntax (char-after)))
              (move-overlay (pop overlays) (point) (1+ (point)))
              (forward-sexp)
              (move-overlay (pop overlays) (1- (point)) (point)))
             ;; Close parenthesis ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
             ((eq ?\) (char-syntax (char-before)))
              (move-overlay (pop overlays) (1- (point)) (point))
              (backward-sexp)
              (move-overlay (pop overlays) (point) (1+ (point)))))
          (error nil))))))

(defun hl-create-parens-internal ()
  ;; outward overlays.
  (unless hl-outward-parens
    (let ((fg hl-outward-paren-fg-colors)
          (bg hl-outward-paren-bg-colors))
      (while (or fg bg)
        (let (facespec)
          (when fg
            (setq facespec (append facespec `((foreground-color . ,(car fg))))))
          (pop fg)
          (when bg
            (setq facespec (append facespec `((background-color . ,(car bg))))))
          (pop bg)
          ;; Make pair overlays.
          (dotimes (i 2)
            (push (make-overlay 0 0) hl-outward-parens)
            (overlay-put (car hl-outward-parens) 'face facespec))))
      (setq hl-outward-parens (reverse hl-outward-parens))))
  ;; inward overlays.
  (unless hl-inward-parens
    (let ((fg hl-inward-paren-fg-color)
          (bg hl-inward-paren-bg-color)
          facespec)
      (when fg
        (setq facespec (append facespec `((foreground-color . ,fg)))))
      (when bg
        (setq facespec (append facespec `((background-color . ,bg)))))
      ;; Make pair overlays.
      (dotimes (i 2)
        (push (make-overlay 0 0) hl-inward-parens)
        (overlay-put (car hl-inward-parens) 'face facespec)))))

(defun hl-remove-parens ()
  (when (hl-paren-is-begin)
    (when hl-paren-timer
      (cancel-timer hl-paren-timer)
      (setq hl-paren-timer nil))
    (mapc 'delete-overlay hl-outward-parens)
    (mapc 'delete-overlay hl-inward-parens)
    (mapc 'kill-local-variable '(hl-outward-parens
                                 hl-inward-parens))))

(provide 'hl-anything)
