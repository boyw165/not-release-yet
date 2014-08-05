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

(require 'ido)
(require 'cus-edit)
(require 'widget)
(require 'wid-edit)
(require 'search-list)

(defgroup prj-group nil
  "Project.")

(defun prj--cus-set-workspace (symbol value)
  "Make sure workspace folder is present."
  (when (stringp value)
    (unless (file-exists-p value)
      (make-directory value)
      )
    (set symbol value)
    )
  )

(defcustom prj-workspace-path "~/.emacs.d/.workspace"
  "The workspace path which is the place storing all the projects' configurations."
  :type '(string)
  :set 'prj--cus-set-workspace
  :group 'prj-group)

(defcustom prj-document-types '(("Text" . ".txt")
				("Lisp" . "*.el")
				("Python" . "*.py")
				("C/C++" . "*.h;*.c;*.hpp;*.cpp")
				("GNU Project" . "Makefile;makefile;Configure.ac;configure.ac"))
  "Categorize file names refer to specific matches and give them type names. It is a list of (DOC_NAME . MATCHES). Each matches in MATCHES should be delimit with ';'."
  ;; TODO: give GUI a pretty appearance.
  :type '(repeat (cons string string))
  :group 'prj-group)

(defconst prj-config-name "config.el"
  "The file name of project configuration.")

(defconst prj-file-db-name "files.txt"
  "The file name of project file-list database.")

(defconst prj-search-db-name "search.txt"
  "The simple text file which caches the search result that users have done in the last session.")

(defvar prj-current-project-name nil
  "The current project's name.")

(defvar prj-current-project-doctypes nil
  "The current project's document types.")

(defvar prj-current-project-filepath nil
  "The current project's file path.")

(defvar prj-current-project-exclude-matches nil
  "The current project's exclude matches.")

(defvar prj-tmp-project-name nil)

(defvar prj-tmp-project-doctypes nil)

(defvar prj-tmp-project-filepath nil)

(defvar prj-tmp-project-exclude-matches nil)

(defvar prj-current-project-config nil
  "The current project's configuration.")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun prj--config-path ()
  (expand-file-name (concat prj-workspace-path "/" prj-current-project-name "/" prj-config-name)))

(defun prj--file-db-path ()
  (expand-file-name (concat prj-workspace-path "/" prj-current-project-name "/" prj-file-db-name)))

(defun prj--search-db-path ()
  (expand-file-name (concat prj-workspace-path "/" prj-current-project-name "/" prj-search-db-name)))

(defun prj--build-file-db ()
  (let* ((matches (plist-get prj-current-project-config :match))
	 (includes (plist-get prj-current-project-config :include))
	 (db-path (prj--file-db-path))
	 (buffer (find-file-noselect db-path)))
    (message "[Prj] Building file list ...")
    (with-current-buffer buffer
      ;; Erase old content.
      (erase-buffer)
      ;; Create file database.
      ;; 1. For file.
      (dolist (f (split-string includes " " t))
	(unless (file-directory-p f)
	  (princ (expand-file-name f) buffer)
	  (princ "\n" buffer)
	  )
	)
      ;; 2. For directory.
      (call-process-shell-command (format "find %s -type f %s 2>/dev/null" includes matches) nil buffer nil)
      ;; Save new content.
      (save-buffer)
      (kill-buffer)
      )
    (message "[Prj] Building file list ...done")
    )
  )

(defun prj--build-tags ()
  ;; TODO: implemnt it.
  )

(defun prj--init-widget-variables ()
  (set (make-local-variable 'widget-documentation-face) 'custom-documentation)
  (set (make-local-variable 'widget-button-face) custom-button)
  (set (make-local-variable 'widget-button-pressed-face) custom-button-pressed)
  (set (make-local-variable 'widget-mouse-face) custom-button-mouse)
  ;; When possible, use relief for buttons, not bracketing.
  (when custom-raised-buttons
    (set (make-local-variable 'widget-push-button-prefix) " ")
    (set (make-local-variable 'widget-push-button-suffix) " ")
    (set (make-local-variable 'widget-link-prefix) "")
    (set (make-local-variable 'widget-link-suffix) ""))
  (setq show-trailing-whitespace nil)
  )

;;;###autoload
(defun prj-document-type ()
  (interactive)
  )

;;;###autoload
(defun prj-create-project ()
  (interactive)
  (switch-to-buffer "*Create Project*")
  (kill-all-local-variables)
  (let ((inhibit-read-only t))
    (erase-buffer))
  (remove-overlays)
  (prj--init-widget-variables)

  (setq prj-tmp-project-name nil)
  (setq prj-tmp-project-doctypes nil)
  (setq prj-tmp-project-exclude-matches ".svn;.git")
  (setq prj-tmp-project-filepath nil)

  (widget-insert "=== Create New Project ===\n")
  (widget-insert "\n")
  (widget-create 'editable-field
		 :format "Project Name: %v"
		 :notify (lambda (wid &rest ignore)
			   (setq prj-tmp-project-name (widget-value wid))))
  (widget-insert "\n")
  (widget-insert "Document Types (Edit):\n") ;; TODO: add customizable link
  (dolist (type prj-document-types)
    (widget-put (widget-create 'checkbox
			       :format (concat "%[%v%] " (car type) "\n")
			       :notify (lambda (wid &rest ignore)
					 (if (widget-value wid)
					     (push (widget-get wid :doc-type) prj-tmp-project-doctypes)
					   (setq prj-tmp-project-doctypes
						 (delq (widget-get wid :doc-type) prj-tmp-project-doctypes)))
					 ))
		:doc-type type)
    )
  (widget-insert "\n")
  (widget-create 'editable-field
		 :value prj-tmp-project-exclude-matches
		 :format "Exclude Matches: %v"
		 :notify (lambda (wid &rest ignore)
			   (setq prj-tmp-project-exclude-matches (widget-value wid))))
  (widget-insert "\n")
  (widget-insert "Include Path:\n")
  (widget-create 'editable-list
		 :entry-format "%i %d %v"
		 :value '("")
		 :notify (lambda (wid &rest ignore)
		 	   (setq prj-tmp-project-filepath (widget-value wid)))
		 '(editable-field :value ""))
  (widget-insert "\n")
  (widget-create 'push-button
		 :notify (lambda (&rest ignore)
			   (message "[Prj] Creating new project ...")
			   (if (or (null prj-tmp-project-name)
			   	   (null prj-tmp-project-doctypes)
			   	   (null prj-tmp-project-exclude-matches)
			   	   (null prj-tmp-project-filepath))
			       (error "[Prj] Can't create new project due to invalid information."))
			   (let* ((path (prj--config-path))
				  (file (find-file-noselect path))
				  (dir (file-name-directory path))
				  (print-quoted t))
			     (unless (file-directory-p dir)
			       (make-directory dir))
			     (with-current-buffer file
			       (erase-buffer)
			       
			       (princ (concat "(setq prj-tmp-project-name " (pp-to-string prj-tmp-project-name) ")") file)
			       (princ "\n" file)
			       
			       (princ (concat "(setq prj-tmp-project-doctypes '" (pp-to-string prj-tmp-project-doctypes) ")") file)
			       (princ "\n" file)
			       
			       (princ (concat "(setq prj-tmp-project-exclude-matches " (pp-to-string prj-tmp-project-exclude-matches) ")") file)
			       (princ "\n" file)
			       
			       (princ (concat "(setq prj-tmp-project-filepath '" (pp-to-string prj-tmp-project-filepath) ")") file)
			       (princ "\n" file)

			       (save-buffer)
			       (kill-buffer)
			       )
			     ;; Kill this form.
			     (kill-buffer)
			     (message "[Prj] Creating new project ...done")
			     ))
			   "ok")
  (widget-insert " ")
  (widget-create 'push-button
		 :notify (lambda (&rest ignore)
			   (kill-buffer))
		 "cancel")

  (goto-char 43)
  (use-local-map widget-keymap)
  (widget-setup)
  )

;;;###autoload
(defun prj-delete-project ()
  (interactive)
  ;; TODO: implemnt it.
  )

;;;###autoload
(defun prj-load-project ()
  "List available prjects in current workspace and let user to choose which project to be loaded."
  (interactive)
  (let (choices prj-dir full-path)
    ;; Find available directories which represent a project.
    (dolist (file (directory-files prj-workspace-path))
      (setq prj-dir file
	    full-path (concat prj-workspace-path "/" file))
      (when (and (file-directory-p full-path)
		 (not (member file '("." ".."))))
	(dolist (file (directory-files full-path))
	  (when (string-equal file prj-config-name)
	    (push prj-dir choices)
	    )
	  )
	)
      )
    (let ((dir (ido-completing-read "[Prj] Load project: " choices)))
      (when (not (member dir '("" "." "..")))
	(setq prj-current-project-name dir)
	;; Read buffer
	(let ((buffer (find-file-noselect (prj--config-path))))
	  ;; The buffer is Lisp script, so execute it.
	  (eval-buffer buffer)
	  (kill-buffer buffer)
	  )
	(message "[Prj] Load project, %s ...done" prj-current-project-name)
	)
      )
    )
  )

;;;###autoload
(defun prj-build-database ()
  "Build file list and tags."
  (interactive)
  ;; Create file list which is the data base of the project's files.
  (when prj-current-project-config
    (prj--build-file-db)
    (prj--build-tags)
    )
  )

;;;###autoload
(defun prj-find-file ()
  "Open file by the given name `name'."
  (interactive)
  ;; Load project if `prj-current-project-config' is nil.
  (unless prj-current-project-config
    (prj-load-project))
  ;; TODO: Support history.
  ;; TODO: Support auto-complete.
  ;; Find.
  (let* ((buffer (find-file-noselect (prj--file-db-path)))
	 db
	 file)
    (with-current-buffer buffer
      (setq db (split-string (buffer-string) "\\(\n\\|\r\\)" t)
	    file (ido-completing-read "[Prj] Find file: " db))
      )
    (find-file file)
    (kill-buffer buffer)
    )
  )

;;;###autoload
(defun prj-search-string ()
  "Search string in the project. Append new search result to the old caches if `new' is nil."
  (interactive)
  ;; Load project if `prj-current-project-config' is nil.
  (unless prj-current-project-config
    (prj-load-project))
  ;; TODO: Support history.
  ;; TODO: Support auto-complete.
  (let ((str (read-from-minibuffer "[Prj] Search string: ")))
    (when (not (string-equal str ""))
      (message "[Prj] Searching %s..." str)
      (let* ((search-db-file (find-file (prj--search-db-path))))
	;; Add title.
	(end-of-buffer)
	(princ (format "=== Search: %s ===\n" str) search-db-file)
	;; Search.
	(call-process-shell-command (format "xargs grep -nH \"%s\" < %s" str (prj--file-db-path)) nil search-db-file nil)
	;; Cache search result.
	(princ "\n" search-db-file)
	(save-buffer)
	)
      )
    )
  )

;;;###autoload
(defun prj-toggle-search-buffer ()
  (interactive)
  )

(provide 'prj)
