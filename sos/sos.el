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

;; Required modules.
(require 'sos-nav)

;; Default supported back-ends.
(require 'sos-grep)
(require 'sos-elisp)
(require 'sos-semantic)

(defgroup sos-group nil
  "A utility to show you documentation at button window by finding some 
meaningful information around the point."
  :tag "Sos")

(defface sos-hl
  '((t (:background "yellow")))
  "Default face for highlighting the current line in Hl-Line mode."
  :group 'sos-group)

(defcustom sos-frontends '(sos-reference-buffer-frontend
                           sos-tips-frontend)
  "The list of front-ends for the purpose of visualization.

`:show': When the visualization should start.

`:hide': When the visualization should end.

`:update': When the data has been updated."
  :type '(repeat (symbol :tag "Front-end"))
  :group 'sos-group)

(defcustom sos-backends '(sos-grep-backend
                          sos-elisp-backend)
  "The list of back-ends for the purpose of collecting candidates. The sos 
engine will dispatch all the back-ends and pass specific commands in order. 
Every command has its purpose, paremeter rule and return rule (get meaningful 
symbol name around the point, find candidates refer to a symbol name). By 
passing command and get return data from a back-end, the sos engine gets 
information to show the result to another window, minibuffer or popup a GUI 
dialog, etc. Be aware, not every back-ends will be dispatched. If a back-end 
return candidates to sos engine, it inform the sos engine that there's no need 
to dispatch remaining back-ends.

### The sample of a back-end:

  (defun some-backend (command &rest args)
    (case command
      (:init t)
      (:symbol (and (member major-mode MAJOR_MODE_CANDIDATES)
                    (thing-at-point 'symbol))))
      (:candidates (list STRING01 STRING02 STRING03 ...))
      (:tips TIPS)
      (:no-cache t))

Each back-end is a function that takes a variable number of arguments. The
first argument is the command requested from the sos enine.  It is one of
the following:

### The order of the commands to be called by sos engine, begins from top to down:

`:init': Called once for each buffer. The back-end can check for external
programs and files and load any required libraries.  Raising an error here
will show up in message log once, and the back-end will not be used for
completion.

`:symbol': The back-end should return a string, nil or 'stop.
Return a string which represents a symbol name tells sos engine that the back
-end will take charge current task. The back-end collect the string around the
point and produce a meaningful symbol name. It also tells sos engine don't
iterate the following back-ends.
Return nil tells sos engine to skip the back-end.
Return `:stop' tells sos engine to stop iterating the following back-ends.
Return value will be cached to `sos-symbol'.

`:candidates': The back-end should return a $CANDIDATES list or nil.
Return a list tells sos engine where the definition is and it must be a list
even if there's only one candidate. It also tells sos engine don't iterate the
following back-ends.
Return nil tells sos engine it cannot find any definition and stop iterating
the following back-ends.
Return value will be cached to `sos-candidates'.

 $CANDIDATES format (alist):
 ((:file STRING
   :offset INTEGER
   :linum INTEGER
   :hl-line BOOLEAN
   :hl-word STRING) ...)

   FILE: A string which indicates the absolute path of the source file.

   OFFSET: A integer which indicates the location of the symbol in the source file.

   HIGHLIGHT: A boolean which indicate to highlight the symbol.

sample:
  TODO: sample

### Optional commands (no sequent order):

`:tips': The back-end should return a string or nil. The return string represents 
a documentation for a completion candidate. The second argument is `sos-symbol' 
which is returned from `:symbol' command.
The sos engine will iterate the candidates and ask for each candidate its `tips'."
  :type '(repeat (symbol :tag "Back-end"))
  :group 'sos-group)

(defcustom sos-idle-delay 0.25
  "The idle delay in seconds until sos starts automatically."
  :type '(number :tag "Seconds"))

(defvar sos-timer nil)

(defvar sos-reference-buffer nil)

(defvar sos-reference-window nil)

(defvar sos-reference-window-height 0)

(defvar sos-hl-face 'sos-hl)

(defvar sos-hl-overlay nil
  "The overlay for `sos-reference-buffer'.")

(defvar sos-backend nil
  "The back-end which takes control of current session in the back-ends list.")
(make-variable-buffer-local 'sos-backend)

(defvar sos-symbol nil
  "Cache the return value from back-end with `:symbol' command.")
(make-variable-buffer-local 'sos-symbol)

(defvar sos-candidates nil
  "Cache the return value from back-end with `:candidates' command.")
(make-variable-buffer-local 'sos-candidates)

(defvar sos-tips nil
  "Cache the return value from back-end with `:tips' command.")
(make-variable-buffer-local 'sos-tips)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (with-current-buffer)
(defmacro sos-with-reference-buffer (&rest body)
  (declare (indent 0) (debug t))
  `(and (window-live-p sos-reference-window)
        (buffer-live-p sos-reference-buffer)
        (with-selected-window sos-reference-window
          (with-current-buffer sos-reference-buffer
            (progn ,@body)
            ;; Minor modes.
            (sos-nav-mode 1)))))

;; (with-temp-buffer)

(defun sos-is-skip-command (&rest commands)
  (member this-command `(mwheel-scroll
                         save-buffer
                         eval-buffer
                         eval-last-sexp
                         ;; Additional commands.
                         ,@commands)))

(defun sos-is-single-candidate ()
  (= (length sos-candidates) 1))

(defun sos-reference-buffer-frontend (command &rest args)
  (case command
    (:show
     ;; TODO: multiple candidates `sos-is-single-candidate'.
     (if (sos-is-single-candidate)
         (let* ((candidate (car sos-candidates))
                (file (plist-get candidate :file))
                (offset (plist-get candidate :offset))
                (linum (plist-get candidate :linum))
                (hl-line (plist-get candidate :hl-line))
                (hl-word (plist-get candidate :hl-word)))
           (when (file-exists-p file)
             (sos-with-reference-buffer
               (insert-file-contents file nil nil nil t)
               ;; Find a appropriate major-mode for it.
               (dolist (mode auto-mode-alist)
                 (and (not (null (cdr mode)))
                      (string-match (car mode) file)
                      (funcall (cdr mode))))
               ;; Move point and recenter.
               (or (and linum (goto-char (point-min))
                        (forward-line (- linum 1)))
                   (and offset (goto-char offset)))
               (recenter 3)
               ;; Highlight word or line.
               (or (and (stringp hl-word)
                        ;; TODO: hl-word.
                        ;; (move-overlay)
                        )
                   (and hl-line
                        (move-overlay sos-hl-overlay (line-beginning-position) (+ 1 (line-end-position))))))))))
    (:hide nil)
    (:update nil)))

(defun sos-tips-frontend (command &rest args)
  (case command
    (:show
     (when (stringp sos-tips)
       ;; TODO: draw a overlay.
       ;; (message "%s" sos-tips)
       ))
    (:hide nil)
    (:update nil)))

(defun sos-pre-command ()
  (when sos-timer
    (cancel-timer sos-timer)
    (setq sos-timer nil)))

(defun sos-post-command ()
  (and (sos-is-idle-begin)
       ;;;;;; Begin instantly.
       (or nil
           (and (= sos-idle-delay 0)
                (sos-idle-begin (current-buffer) (point)))
           ;; Begin with delay `sos-idle-delay'
           (setq sos-timer (run-with-timer sos-idle-delay nil
                                           'sos-idle-begin
                                           (current-buffer) (point))))))

(defun sos-is-idle-begin ()
  (not (or (eq (current-buffer) sos-reference-buffer)
           (eq (selected-window) sos-reference-window)
           (sos-is-skip-command))))

(defun sos-idle-begin (buf pt)
  (and (eq buf (current-buffer))
       (eq pt (point))
       (if (null sos-backend)
           (sos-1st-process-backends)
         (sos-process-backend sos-backend))))

(defun sos-1st-process-backends ()
  (dolist (backend sos-backends)
    (sos-process-backend backend)
    (and sos-backend
         (return t)))
  t)

(defun sos-process-backend (backend)
  (let ((symb (sos-call-backend backend :symbol)))
    (cond
     ;; Return a string ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
     ((stringp symb)
      (if (string-equal symb sos-symbol)
          (progn
            ;; If return symbol string is equal to `sos-symbol', ask front-ends
            ;; Renew the `:tips' and to do `:update' task.
            (setq sos-tips (sos-call-backend backend :tips symb))
            (sos-call-frontends :update))
        ;; Call front-ends: `:hide'.
        (sos-call-frontends :hide)
        (setq sos-backend backend
              sos-symbol symb)
        ;; Call back-end: get `sos-candidates' and `sos-candidate'.
        (setq sos-candidates (sos-call-backend backend :candidates symb)
              sos-tips (sos-call-backend backend :tips symb))
        ;; (sos-call-backend backend :tips symb)
        (and sos-candidates (listp sos-candidates)
             ;; Call front-ends: `:show'.
             (sos-call-frontends :show :update))))

     ;; Return nil ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
     ((null symb)
      (sos-kill-local-variables))

     ;; Return `:stop' ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
     ((eq symb :stop)
      (setq sos-backend backend))))
  t)

(defun sos-kill-local-variables ()
  (mapc 'kill-local-variable '(sos-backend
                               sos-symbol
                               sos-candidates
                               sos-candidate
                               sos-tips)))

(defun sos-call-frontends (command &rest args)
  "Iterate all the `sos-backends' and pass `command' by order."
  (let ((commands (cons command args)))
    (dolist (frontend sos-frontends)
      (dolist (cmd commands)
        (condition-case err
            (funcall frontend cmd)
          (error "[sos] Front-end %s error \"%s\" on command %s"
                 frontend (error-message-string err) commands))))))

(defun sos-call-backend (backend command &optional arg)
  "Call certain backend `backend' and pass `command' to it."
  (condition-case err
      (funcall backend command arg)
    (error "[sos] Back-end %s error \"%s\" on command %s"
           backend (error-message-string err) (cons command arg))))

(defun sos-init-backend (backend)
  (condition-case err
      (progn
        (funcall backend :init))
    (error "[sos] Back-end %s error \"%s\" on command %s"
           backend (error-message-string err) :init)))

;;;###autoload
(define-minor-mode sos-reference-window-mode
  "This local minor mode gethers symbol returned from backends around the point 
and show the reference visually through frontends. Usually frontends output the 
result to the `sos-reference-buffer' displayed in the `sos-reference-window'. 
Show or hide these buffer and window are controlled by `sos-watchdog-mode'."
  :lighter " SOS:Ref"
  :group 'sos-group
  ;; TODO: menu-bar and tool-bar keymap.
  (if sos-reference-window-mode
      (progn
        (unless (eq (current-buffer) sos-reference-buffer)
          (unless sos-watchdog-mode
            (sos-watchdog-mode 1))
          (mapc 'sos-init-backend sos-backends)
          (add-hook 'pre-command-hook 'sos-pre-command nil t)
          (add-hook 'post-command-hook 'sos-post-command nil t)))
    (sos-kill-local-variables)
    (remove-hook 'pre-command-hook 'sos-pre-command t)
    (remove-hook 'post-command-hook 'sos-post-command t)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun sos-toggle-buffer-window (toggle)
  "Display or hide the `sos-reference-buffer' and `sos-reference-window'."
  (let ((enabled (or (and (booleanp toggle) toggle)
                     (and (numberp toggle)
                          (> toggle 0)))))
    (if enabled
        (progn
          (setq sos-reference-buffer (get-buffer-create "*Reference*"))
          (unless (window-live-p sos-reference-window)
            (let* ((win (cond
                         ;; Only one window.
                         ((window-live-p (frame-root-window))
                          (selected-window))
                         (t (selected-window))))
                   (height (or (and (> sos-reference-window-height 0)
                                    (- 0 sos-reference-window-height))
                               (and win
                                    (/ (window-height win) -3)))))
              (and win height
                   (setq sos-reference-window (split-window win height 'below)))))
          ;; Force to apply `sos-reference-buffer' to `sos-reference-window'.
          (set-window-buffer sos-reference-window sos-reference-buffer)
          (sos-with-reference-buffer
            ;; Create highlight line overlay.
            (unless sos-hl-overlay
              (setq sos-hl-overlay (make-overlay 1 1))
              (overlay-put sos-hl-overlay 'face sos-hl-face))))
      (and (windowp sos-reference-window)
           (delete-window sos-reference-window))
      (and (bufferp sos-reference-buffer)
           (kill-buffer sos-reference-buffer))
      (setq sos-reference-buffer nil
            sos-reference-window nil
            sos-hl-overlay nil))))

(defun sos-watchdog-post-command ()
  (condition-case err
      (progn
        (unless (or (sos-is-skip-command 'self-insert-command
                                         'previous-line
                                         'next-line
                                         'left-char
                                         'right-char)
                    (active-minibuffer-window))
          (if sos-reference-window-mode
              ;; Show them.
              (progn
                (sos-toggle-buffer-window 1)
                (setq sos-reference-window-height (window-height sos-reference-window)))
            ;; Hide them or not.
            (cond
             ;; If selected window is `sos-reference-window' and current buffer is
             ;; `sos-reference-buffer':
             ((and (eq (selected-window) sos-reference-window)
                   (eq (current-buffer) sos-reference-buffer)) t)
             ;; If selected window is `sos-reference-window' but its buffer is not
             ;; `sos-reference-buffer':
             ((and (eq (selected-window) sos-reference-window)
                   (not (eq (window-buffer) sos-reference-buffer)))
              (sos-toggle-buffer-window 1))
             ;; Hide by default:
             (t (sos-toggle-buffer-window -1))))))
    (error "[sos] sos-watchdog-post-command error \"%s\""
           (error-message-string err))))

;;;###autoload
(define-minor-mode sos-watchdog-mode
  "A global minor mode which refers to buffer's `sos-reference-window-mode' to show the 
`sos-reference-buffer' and `sos-reference-window' or hide them. Show them if 
`sos-reference-window-mode' is t; Hide if nil."
  :global t
  :group 'sos-group
  (if sos-watchdog-mode
      (add-hook 'post-command-hook 'sos-watchdog-post-command t)
    (remove-hook 'post-command-hook 'sos-watchdog-post-command t)))

(provide 'sos)
