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
;; TODO:
;; - Support keymap (menu and toolbar).
;;           `prj2-create-project', `prj2-delete-project',
;;           `prj2-load-project', `prj2-unload-project',
;;           `prj2-build-database', `prj2-find-file'.
;; - Divide complex computation into piece, let user can interrupt it and save the result before the cancellation.
;; - Support project's local variable.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Change Log:
;;
;; 2014-08-01 (0.0.1)
;;    Initial release.

(require 'ido)
(require 'json)

(require 'prj-grep)
(require 'prj2-widget-frontend)

(defgroup prj2-group nil
  "A Project management utility. This utility provides you a workspace and many projects concept. It also provide you a way to easily find file without knowing its full path; Add different directories with specific document types in a project; Powerful selective grep string or regular expression in a project, etc."
  :tag "Prj")

(defun prj2-cus-set-workspace (symbol value)
  "Make sure the directory is present."
  (when (stringp value)
    (unless (file-exists-p value)
      (make-directory value))
    (when (file-exists-p value)
      (set symbol (expand-file-name value)))))

(defcustom prj2-workspace-path "~/.emacs.d/.workspace"
  "The place storing all the projects' configurations."
  :type '(string)
  :set 'prj2-cus-set-workspace
  :group 'prj2-group)

(defcustom prj2-document-types '(("Text" . "*.txt;*.md;*.xml")
                                ("Emacs Lisp" . ".emacs;*.el")
                                ("Python" . "*.py")
                                ("Java" . "*.java")
                                ("C/C++ Header" . "*.h;*.hxx;*.hpp")
                                ("C/C++ Source" . "*.c;*.cpp")
                                ("Makfile" . "Makefile;makefile;Configure.ac;configure.ac;*.mk"))
  "Categorize file names refer to specific matches and give them type names. It is a alist of (DOC_NAME MATCHES). Each matches in MATCHES should be delimit with ';'."
  ;; TODO: give GUI a pretty appearance.
  :type '(repeat (cons (string :tag "Type")
                       (string :tag "File")))
  :group 'prj2-group)

(defcustom prj2-exclude-types ".git;.svn"
  "Those kinds of file should be excluded in the project. Each matches should be delimit with ';'."
  ;; TODO: give GUI a pretty appearance.
  :type '(string :tag "File")
  :group 'prj2-group)

(defcustom prj2-create-project-frontends '(prj2-create-project-widget-frontend)
  ""
  :type '(repeat (symbol :tag "Front-end"))
  :group 'prj2-group)

(defcustom prj2-delete-project-frontends '(prj2-delete-project-widget-frontend)
  ""
  :type '(repeat (symbol :tag "Front-end"))
  :group 'prj2-group)

(defcustom prj2-edit-project-frontends '(prj2-edit-project-widget-frontend)
  ""
  :type '(repeat (symbol :tag "Front-end"))
  :group 'prj2-group)

(defcustom prj2-search-project-frontends '(prj2-search-project-widget-frontend)
  ""
  :type '(repeat (symbol :tag "Front-end"))
  :group 'prj2-group)

(defcustom prj2-find-file-frontends '(prj2-find-file-frontend)
  ""
  :type '(repeat (symbol :tag "Front-end"))
  :group 'prj2-group)

(defvar prj2-config nil
  "A plist which represent a project's configuration, it will be exported as format of JSON file.
format:
  (:name NAME                                // NAME is a string.
   :filepaths (PATH1 PATH2 ...)              // PATH is a string.
   :doctypes (DOC_NAME1 DOC_TYPE1            // e.g. (\"Emacs Lisp\" \".emacs;*.el\"
              DOC_NAME2 DOC_TYPE2                     \"Text\"       \"*.txt;*.md\"
              ...)                                    ...).
   :recent-files (FILE1 FILE2 ...)           // FILE is a string.
   :search-history (KEYWORD1 KEYWORD2 ...))  // KEYWORD is a string.")

(defconst prj2-config-name "config.db"
  "The file name of project configuration. see `prj2-config' for detail.")

(defconst prj2-filedb-name "files.db"
  "The file name of project file-list database. The database is a plist which 
contains files should be concerned.
format:
  (DOCTYPE1 (FILE1_1 FILE1_2 ...)
   DOCTYPE2 (FILE2_1 FILE2_2 ...))")

(defconst prj2-searchdb-name "search.db"
  "The simple text file which caches the search result that users have done in the last session.")

(defconst prj2-search-history-max 16
  "Maximin elements count in the searh history cache.")

(defconst prj2-idle-delay 0.5)

(defvar prj2-timer nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;###autoload
(defun prj2-preference ()
  "Customize document types."
  (interactive)
  (customize-group 'prj2-group))

;;;###autoload
(defun prj2-create-project ()
  "Show configuration for creating new project."
  (interactive)
  (prj2-clean-frontends)
  (prj2-call-frontends :show
                       prj2-create-project-frontends
                       'prj2-create-project-begin))

;;;###autoload
(defun prj2-delete-project ()
  "Show configuration for deleting projects."
  (interactive)
  (prj2-clean-frontends)
  (prj2-call-frontends :show
                       prj2-delete-project-frontends
                       'prj2-delete-project-begin))

;;;###autoload
(defun prj2-edit-project ()
  "Show configuration for editing project's setting."
  (interactive)
  (prj2-clean-frontends)
  ;; Load project if wasn't loaded.
  (unless (prj2-project-p)
    (prj2-load-project))
  (prj2-call-frontends :show
                       prj2-edit-project-frontends
                       'prj2-edit-project-begin))

;;;###autoload
(defun prj2-load-project (&optional name)
  "List available prjects in current workspace and let user to choose which 
project to be loaded."
  (interactive)
  (let (choices)
    (unless name
      ;; Find available directories which represent a project.
      (dolist (name (directory-files prj2-workspace-path))
        (let ((config-file (prj2-config-path name)))
          (when (and (file-exists-p config-file)
                     (not (string= name (prj2-project-name))))
            (setq choices (append choices `(,name))))))
      ;; Prompt user to create project if no projects is in workspace.
      (when (= (length choices) 0)
        (error "No project can be loaded! Please create a project first."))
      ;; Prompt user to load project.
      (setq name (ido-completing-read "Load project: " choices nil t)))
    (prj2-clean-all)
    ;; Read configuration.
    (setq prj2-config (prj2-import-json (prj2-config-path name)))
    ;; Update database
    (prj2-build-database)
    (and (featurep 'sos)
         (unless sos-definition-window-mode
           (sos-definition-window-mode 1)))
    (message "Load [%s] ...done" (prj2-project-name))))

;;;###autoload
(defun prj2-load-recent-project ()
  "Load the project which user exits emacs last time."
  (interactive)
  ;; TODO:
  nil)

;;;###autoload
(defun prj2-unload-project ()
  "Unload current project."
  (interactive)
  (let ((name (prj2-project-name)))
    (prj2-clean-all)
    (message "Unload [%s] ...done" name)))

;;;###autoload
(defun prj2-build-database ()
  "Build file list and tags."
  (interactive)
  (unless (prj2-project-p)
    (prj2-load-project))
  ;; Create file list which is the data base of the project's files.
  (when (prj2-project-p)
    (message "Build database might take a minutes, please wait ...")
    (prj2-build-filedb)
    (prj2-build-tags)
    (message "Database is updated!")))

;;;###autoload
(defun prj2-find-file ()
  "Open file by the given file name."
  (interactive)
  (prj2-clean-frontends)
  ;; Load project if wasn't loaded.
  (unless (prj2-project-p)
    (prj2-load-project))
  (prj2-call-frontends :show
                       prj2-find-file-frontends
                       'prj2-find-file-begin))

;;;###autoload
(defun prj2-search-project ()
  "Search string in the project. Append new search result to the old caches if `new' is nil."
  (interactive)
  ;; Load project if no project was loaded.
  (unless (prj2-project-p)
    (prj2-load-project))
  (prj2-call-frontends :show
                       prj2-search-project-frontends
                       'prj2-search-project-begin))

;;;###autoload
(defun prj2-toggle-search-buffer ()
  (interactive)
  ;; TODO: bug when user is select definition window and try to toggle search buffer off.
  (if (equal (buffer-name (current-buffer)) "*Search*")
      ;; Back to previous buffer of current window.
      (progn
        (and (buffer-modified-p)
             (save-buffer 0))
        (kill-buffer))
    ;; Go to search buffer.
    (unless (prj2-project-p)
      (prj2-load-project))
    (prj2-with-search-buffer)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;###autoload
(define-minor-mode prj2-project-mode
  "Provide convenient menu items and tool-bar items for project feature."
  :lighter " Project"
  :global t
  (if prj2-project-mode
      (progn
        )
    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun prj2-call-frontends (command frontends &optional ok)
  "Call frontends and pass ok callback functions to them. If one of them returns 
non nil, the loop will break."
  (dolist (frontend frontends)
    (and (funcall frontend command ok)
         (return t))))

(defun prj2-clean-frontends ()
  (dolist (frontends `(,prj2-create-project-frontends
                       ,prj2-delete-project-frontends
                       ,prj2-edit-project-frontends
                       ,prj2-search-project-frontends
                       ,prj2-find-file-frontends))
    (prj2-call-frontends :hide frontends)))

(defun prj2-clean-all ()
  "Clean search buffer or widget buffers which belongs to other project when user loads a project or unload a project."
  ;; Clean widgets.
  (dolist (frontends `(,prj2-create-project-frontends
                       ,prj2-delete-project-frontends
                       ,prj2-edit-project-frontends
                       ,prj2-search-project-frontends
                       ,prj2-find-file-frontends))
    (prj2-call-frontends :hide frontends))
  ;; Kill search buffer.
  (let ((search (get-buffer "*Search*")))
    (and search
         (with-current-buffer search
           (save-buffer)
           (kill-buffer))))
  ;; Reset configuration.
  (setq prj2-config nil))

(defun prj2-create-project-begin (name doctypes filepaths)
  (when prj2-timer
    (cancel-timer prj2-timer))
  (setq prj2-timer (run-with-timer prj2-idle-delay nil
                                   'prj2-create-project-internal
                                   name doctypes filepaths)))

(defun prj2-create-project-internal (name doctypes filepaths)
  "Internal function to create project. It is called by functions in the 
`prj2-create-project-frontends'."
  (let* ((path (prj2-config-path name))
         (fullpath (expand-file-name path))
         (dir (file-name-directory fullpath))
         (config (prj2-new-config)))
    ;; Prepare project directory.
    (unless (file-directory-p dir)
      (make-directory dir))
    ;; Export configuration.
    (prj2-plist-put config :name name)
    (prj2-plist-put config :doctypes doctypes)
    (prj2-plist-put config :filepaths filepaths)
    (prj2-export-json path config)
    ;; Load project.
    (prj2-load-project name)
    ;; Build database.
    (prj2-build-database)))

(defun prj2-edit-project-begin (doctypes filepaths)
  (when prj2-timer
    (cancel-timer prj2-timer)
    (setq prj2-timer nil))
  (setq prj2-timer (run-with-timer prj2-idle-delay nil
                                   'prj2-edit-project-internal
                                   doctypes filepaths)))

(defun prj2-edit-project-internal (doctypes filepaths)
  "Internal function to edit project. It is called by functions in the 
`prj2-edit-project-frontends'."
  (prj2-plist-put prj2-config :doctypes doctypes)
  (prj2-plist-put prj2-config :filepaths filepaths)
  (prj2-export-json (prj2-config-path) prj2-config)
  ;; Update database.
  (prj2-build-filedb))

(defun prj2-delete-project-begin (projects)
  (when prj2-timer
    (cancel-timer prj2-timer)
    (setq prj2-timer nil))
  (setq prj2-timer (run-with-timer prj2-idle-delay nil
                                   'prj2-delete-project-internal
                                   projects)))

(defun prj2-delete-project-internal (projects)
  "Internal function to delete project. It is called by functions in the 
`prj2-delete-project-frontends'."
  (dolist (project projects)
    ;; Unload current project if it is selected.
    (when (and (prj2-project-p)
	       (string= project (prj2-project-name)))
      (prj2-unload-project))
    ;; Delete directory
    (delete-directory (format "%s/%s" prj2-workspace-path project) t t))
  (message "Delet project ...done"))

(defmacro prj2-with-search-buffer (&rest body)
  (declare (indent 0) (debug t))
  `(progn
     (find-file (prj2-searchdb-path))
     (rename-buffer "*Search*")
     (goto-char (point-max))
     (save-excursion
       (progn ,@body))
     (and (buffer-modified-p)
          (save-buffer 0))
     ;; TODO: goto last search result.
     ;; Change major mode.
     (prj2-grep-mode)))

(defun prj2-search-project-begin (match projects)
  (when prj2-timer
    (cancel-timer prj2-timer)
    (setq prj2-timer nil))
  (setq prj2-timer (run-with-timer prj2-idle-delay nil
                                   'prj2-search-project-internal
                                   )))

(defun prj2-search-project-internal (match projects)
  "Internal function to edit project. It is called by functions in the 
`prj2-search-project-frontends'."
  ;; Cache search string.
  (let ((cache (prj2-project-search-history)))
    (push match cache)
    (and (> (length cache) prj2-search-history-max)
         (setcdr (nthcdr (1- prj2-search-history-max) cache) nil))
    (puthash :search-cache cache prj2-config)
    (prj2-export-json (prj2-config-path) prj2-config))
  ;; Create search buffer.
  (prj2-with-search-buffer
    (let ((db (prj2-import-data (prj2-filedb-path)))
          (files '()))
      (insert (format ">>>>> %s\n" match))
      ;; Prepare file list.
      (dolist (elm projects)
        (dolist (f (gethash elm db))
          (message "Searching ...%s" f)
          (goto-char (point-max))
          (call-process "grep" nil (list (current-buffer) nil) t "-nH" match f)))
      (insert "<<<<<\n\n")
      (message (format "Search ...done")))))

(defun prj2-find-file-begin (file)
  (and (featurep 'history)
       (his-add-position-type-history))
  (find-file file)
  (and (featurep 'history)
       (his-add-position-type-history)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmacro prj2-plist-put (plist prop val)
  `(setq ,plist (plist-put ,plist ,prop ,val)))

(defun prj2-config-path (&optional name)
  (expand-file-name (format "%s/%s/%s"
                            prj2-workspace-path
                            (or name
                                (prj2-project-name))
                            prj2-config-name)))

(defun prj2-filedb-path ()
  (expand-file-name (format "%s/%s/%s"
                            prj2-workspace-path
                            (prj2-project-name)
                            prj2-filedb-name)))

(defun prj2-searchdb-path ()
  (expand-file-name (format "%s/%s/%s"
                            prj2-workspace-path
                            (prj2-project-name)
                            prj2-searchdb-name)))

(defun prj2-project-name ()
  (plist-get prj2-config :name))

(defun prj2-project-doctypes ()
  (plist-get prj2-config :doctypes))

(defun prj2-project-filepaths ()
  (plist-get prj2-config :filepaths))

(defun prj2-project-recent-files ()
  (plist-get prj2-config :recent-files))

(defun prj2-project-search-history ()
  (plist-get prj2-config :search-history))

(defun prj2-project-p ()
  "Return t if any project was loaded (current project)."
  (and prj2-config
       (plist-get prj2-config :name)))

(defun prj2-new-config ()
  "Return a config template."
  (let (config)
    (prj2-plist-put config :name "")
    (prj2-plist-put config :filepaths '())
    (prj2-plist-put config :doctypes '())
    (prj2-plist-put config :recent-files '())
    (prj2-plist-put config :search-history '())
    config))

(defun prj2-export-json (filename data)
  "Export `data' to `filename' file. The saved data can be imported with `prj2-import-data'."
  (when (file-writable-p filename)
    (with-temp-file filename
      (insert (json-encode-plist data)))))

;; (setq prj2-config (prj2-import-json "/Users/Boy/.emacs.d/.workspace/Test/config.db"))
(defun prj2-import-json (filename)
  "Read data exported by `prj2-export-json' from file `filename'."
  (when (file-exists-p filename)
    (let ((json-object-type 'plist)
          (json-key-type 'keyword)
          (json-array-type 'list))
      (json-read-file filename))))

(defun prj2-export-data (filename data)
  "Export `data' to `filename' file. The saved data can be imported with `prj2-import-data'."
  (when (file-writable-p filename)
    (with-temp-file filename
      (insert (let (print-length)
		(prin1-to-string data))))))

(defun prj2-import-data (filename)
  "Read data exported by `prj2-export-data' from file `filename'."
  (when (file-exists-p filename)
    (with-temp-buffer
      (insert-file-contents filename)
      (read (buffer-string)))))

(defun prj2-thingatpt ()
  "Return a list, (REGEXP_STRING BEG END), on which the point is or just string of selection."
  (if mark-active
      (buffer-substring-no-properties (region-beginning) (region-end))
    (let ((bound (bounds-of-thing-at-point 'symbol)))
      (and bound
           (buffer-substring-no-properties (car bound) (cdr bound))))))

(defun prj2-convert-filepaths (filepaths)
  "Convert FILEPATHS to string as parameters for find.
e.g. (~/test01\ ~/test02) => test01 test02"
  (and (listp filepaths)
       (let ((path filepaths)
             paths)
         (while path
           (setq paths (concat paths
                               "\"" (expand-file-name (car path)) "\"")
                 path (cdr path))
           (and path
                (setq paths (concat paths " "))))
         paths)))

(defun prj2-convert-matches (doctype)
  "Convert DOCTYPE to string as include-path parameter for find.
e.g. *.md;*.el;*.txt => -name *.md -o -name *.el -o -name *.txt"
  (and (stringp doctype)
       (let ((matches (concat "\"-name\" \"" doctype "\"")))
         (replace-regexp-in-string ";" "\" \"-o\" \"-name\" \"" matches))))

(defun prj2-convert-excludes (doctype)
  "Convert DOCTYPE to string as exclude-path parameter for find.
e.g. .git;.svn => ! -name .git ! -name .svn"
  (and (stringp doctype)
       (let ((matches (concat "\"!\" \"-name\" \"" doctype "\"")))
         (replace-regexp-in-string ";" "\" \"!\" \"-name\" \"" matches))))

(defun prj2-process-find (filepaths matches excludes)
  (let ((filepaths (prj2-convert-filepaths filepaths))
        (matches (prj2-convert-matches matches))
        (excludes (prj2-convert-excludes excludes))
        stream)
    (when (and filepaths matches excludes)
      (setq stream (concat "(with-temp-buffer "
                           "(call-process \"find\" nil (list (current-buffer) nil) nil "
                           filepaths " "
                           matches " "
                           excludes ")"
                           "(buffer-string))"))
      (let ((output (eval (read stream))))
        (and output
             (split-string output "\n" t))))))

(defun prj2-process-find-change ()
  )

(defun prj2-build-filedb ()
  "Create a list that contains all the files which should be included in the current project. Export the list to a file."
  ;; TODO: Find those files which are newer than database, update them.
  (let ((filepaths (prj2-project-filepaths))
        (doctypes (prj2-project-doctypes))
        (excludes prj2-exclude-types)
        db)
    ;; Iterate doctypes.
    (while doctypes
      (let* ((files (prj2-process-find filepaths
                                       (cadr doctypes)
                                       excludes)))
        (prj2-plist-put db (car doctypes) files))
      ;; Next.
      (setq doctypes (cddr doctypes)))
    ;; Export database.
    (prj2-export-data (prj2-filedb-path) db)
    ))

(defun prj2-build-tags ()
  ;; TODO: implemnt it.
  ;; TODO: Find those files which are newer than database, update them.
  )

(provide 'prj2)
