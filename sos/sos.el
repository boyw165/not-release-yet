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

;; Front-ends.
(require 'sos-basic-frontend)

;; Back-ends.
(require 'sos-grep-backend)
(require 'sos-elisp-backend)
(require 'sos-semantic-backend)

(defgroup sos-group nil
  "A utility to show you documentation at button window by finding some 
meaningful information around the point."
  :tag "Sos")

(defface sos-hl
  '((t (:background "yellow" :foreground "black" :weight bold :height 1.5)))
  "Default face for highlighting the current line in Hl-Line mode."
  :group 'sos-group)

(defcustom sos-frontends '(sos-definition-buffer-frontend
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
      (:tips STRING))

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
   :hl-word STRING) (...) ...)

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

(defcustom sos-idle-delay 0.15
  "The idle delay in seconds until sos starts automatically."
  :type '(number :tag "Seconds"))

(defvar sos-timer nil)

(defvar sos-hl-face 'sos-hl)

(defvar sos-hl-overlay nil
  "The overlay for `sos-definition-buffer'.")

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

(defun sos-is-skip-command (&rest commands)
  "Return t if `this-command' should be skipped.
If you want to skip additional commands, try example:

  (sos-is-skip-command 'self-insert-command
                       'previous-line
                       'next-line
                       'left-char
                       'right-char)
"
  (member this-command `(mwheel-scroll
                         save-buffer
                         eval-buffer
                         eval-last-sexp
                         ;; Additional commands.
                         ,@commands)))

(defun sos-is-single-candidate ()
  (= (length sos-candidates) 1))

(defun sos-pre-command ()
  (when sos-timer
    (cancel-timer sos-timer)
    (setq sos-timer nil)))

(defun sos-post-command ()
  (and (sos-is-idle-begin)
       ;;;;;; Begin instantly.
       (or nil
           (and (= sos-idle-delay 0)
                (sos-idle-begin))
           ;; Begin with delay `sos-idle-delay'
           (setq sos-timer (run-with-timer sos-idle-delay nil
                                           'sos-idle-begin)))))

(defun sos-is-idle-begin ()
  (not (or (active-minibuffer-window)
           (eq (current-buffer) sos-definition-buffer)
           (eq (selected-window) sos-definition-window)
           (sos-is-skip-command))))

(defun sos-idle-begin ()
  (if (null sos-backend)
      (sos-1st-process)
    (sos-continue-process sos-backend)))

(defun sos-1st-process ()
  (dolist (backend sos-backends)
    (sos-continue-process backend)
    (if sos-backend
        (return t)
      (sos-call-frontends :hide))))

(defun sos-continue-process (backend)
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
        (setq sos-backend backend
              sos-symbol symb)
        ;; Call back-end: get `sos-candidates' and `sos-candidate'.
        (setq sos-candidates (sos-call-backend backend :candidates symb)
              sos-tips (sos-call-backend backend :tips symb))
        ;; (sos-call-backend backend :tips symb)
        (if (and sos-candidates (listp sos-candidates))
            (sos-call-frontends :show :update)
          (sos-call-frontends :hide))))

     ;; Return nil ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
     ((null symb)
      (sos-kill-local-variables)
      (sos-call-frontends :hide))

     ;; Return `:stop' ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
     ((eq symb :stop)
      (setq sos-backend backend)
      (sos-call-frontends :hide)))))

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
        (funcall frontend cmd)))))

(defun sos-call-backend (backend command &optional arg)
  "Call certain backend `backend' and pass `command' to it."
  (funcall backend command arg))

(defun sos-init-backend (backend)
  (funcall backend :init))

;;;###autoload
(define-minor-mode sos-definition-window-mode
  "This local minor mode gethers symbol returned from backends around the point 
and show the reference visually through frontends. Usually frontends output the 
result to the `sos-definition-buffer' displayed in the `sos-definition-window'. 
Show or hide these buffer and window are controlled by `sos-watchdog-mode'."
  :lighter " SOS:def"
  :global t
  :group 'sos-group
  ;; TODO: menu-bar and tool-bar keymap.
  (if sos-definition-window-mode
      (progn
        (mapc 'sos-init-backend sos-backends)
        (add-hook 'pre-command-hook 'sos-pre-command)
        (add-hook 'post-command-hook 'sos-post-command))
    (sos-call-frontends :hide)
    (remove-hook 'pre-command-hook 'sos-pre-command)
    (remove-hook 'post-command-hook 'sos-post-command)
    (sos-kill-local-variables)))

(provide 'sos)
