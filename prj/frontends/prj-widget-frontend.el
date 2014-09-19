;; Copyright (C) 2014
;;
;; Author: BoyW165
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

(require 'cus-edit)
(require 'widget)
(require 'wid-edit)
(require 'tooltip)
(require 'company)
(require 'company-files)

(defvar prj-ok-func nil)
(make-variable-buffer-local 'prj-ok-func)

(defvar prj-widget-textfield nil)
(make-variable-buffer-local 'prj-widget-textfield)

(defvar prj-widget-checkboxes nil)
(make-variable-buffer-local 'prj-widget-checkboxes)

(defvar prj-widget-filepaths nil)
(make-variable-buffer-local 'prj-widget-filepaths)

(defvar prj-widget-doctypes nil)
(make-variable-buffer-local 'prj-widget-doctypes)

;; (defface prj-title-face
;;   '((t (:background "yellow" :foreground "black" :weight bold :height 2.0)))
;;   "Default face for highlighting keyword in definition window."
;;   :group 'prj-group)

;;;###autoload
(defun prj-create-project-widget-frontend (command &optional ok)
  (case command
    (:show
     (prj-with-widget "*Create Project*"
       ;; Ok implementation callback ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       ok

       ;; Ok notify ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       (lambda (&rest ignore)
         (let ((name (widget-value prj-widget-textfield))
               (doctypes (prj-widget-doctypes))
               (filepaths (prj-widget-filepaths)))
           (unless (> (length name) 0)
             (error "Project name is empty!"))
           (unless (> (length doctypes) 0)
             (error "No document types is selected!"))
           (unless (> (length filepaths) 0)
             (error "No valid file path!"))
           ;; call `prj-create-project-begin' -> `prj-create-project-internal'.
           (and prj-ok-func
                (funcall prj-ok-func name doctypes filepaths))
           (kill-buffer)))

       ;; Body ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       ;; Widget for project name.
       (setq prj-widget-textfield
             (widget-create 'editable-field
                            :format "Project Name: %v"))
       (widget-insert "\n")
       (widget-insert "Document Types (Edit) ") ;; TODO: add customizable link
       (widget-create 'push-button
                      :notify (prj-widget-checkbox-select-all prj-widget-doctypes)
                      "Select All")
       (widget-insert " ")
       (widget-create 'push-button
                      :notify (prj-widget-checkbox-deselect-all prj-widget-doctypes)
                      "Deselect All")
       (widget-insert " :\n")
       ;; Widget for doctypes.
       (let (wid)
         (dolist (doctype prj-document-types)
           (setq wid (widget-create 'checkbox
                                    :data doctype
                                    :format (concat "%[%v%] "
                                                    (prj-format-doctype doctype)
                                                    "\n"))
                 prj-widget-doctypes (append prj-widget-doctypes
                                              `(,wid)))))
       (widget-insert "\n")
       (widget-insert "Include Path:\n")
       (widget-insert (propertize "- Button INS to add a path; Button DEL to \
remove one.\n"
                                  'face 'font-lock-string-face))
       (widget-insert (propertize "- Use TAB to get a path prompt.\n"
                                  'face 'font-lock-string-face))
       ;; Widget for filepaths.
       (setq prj-widget-filepaths
             (widget-create 'editable-list
                            :entry-format "%i %d path: %v"
                            :value '("")
                            ;; Put :company to make company work for it.
                            '(editable-field :company prj-browse-file-backend)))))
    (:hide
     (and (get-buffer "*Create Project*")
          (kill-buffer "*Create Project*")))))

;;;###autoload
(defun prj-delete-project-widget-frontend (command &optional ok)
  (case command
    (:show
     (prj-with-widget "*Delete Project*"
       ;; Ok implementation callback ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       ok

       ;; Ok notify ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       (lambda (&rest ignore)
         (let ((projects (prj-widget-checkboxes)))
           (unless (> (length projects) 0)
             (error "No project is selected!"))
           ;; call `prj-delete-project-begin' -> `prj-delete-project-internal'.
           (and prj-ok-func
                (funcall prj-ok-func projects))
           (kill-buffer)))

       ;; Body ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       (widget-insert "Delete project ")
       (widget-create 'push-button
                      :notify (prj-widget-checkbox-select-all prj-widget-checkboxes)
                      "Select All")
       (widget-insert " ")
       (widget-create 'push-button
                      :notify (prj-widget-checkbox-deselect-all prj-widget-checkboxes)
                      "Deselect All")
       (widget-insert " :\n")
       ;; Widget for project name.
       (let (projects)
         ;; Find out all the projects.
         (dolist (file (directory-files prj-workspace-path))
           (let ((config (prj-config-path file)))
             (when (file-exists-p config)
               (setq projects (append projects
                                      `(,file))))))
         (unless projects
           (kill-buffer)
           (error "No projects can be deleted."))
         (let (wid)
           (dolist (project projects)
             (setq wid (widget-create 'checkbox
                                      :data project
                                      :format (concat "%[%v%] " project "\n"))
                   prj-widget-checkboxes (append prj-widget-checkboxes
                                                  `(,wid))))))))
    (:hide
     (and (get-buffer "*Delete Project*")
          (kill-buffer "*Delete Project*")))))

;;;###autoload
(defun prj-edit-project-widget-frontend (command &optional ok)
  (case command
    (:show
     (prj-with-widget "*Edit Project*"
       ;; Ok implementation callback ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       ok

       ;; Ok notify ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       (lambda (&rest ignore)
         (let ((doctypes (prj-widget-doctypes))
               (filepaths (prj-widget-filepaths)))
           (unless (> (length doctypes) 0)
             (error "No document types is selected!"))
           (unless (> (length filepaths) 0)
             (error "No valid file path!"))
           ;; call `prj-edit-project-begin' -> `prj-edit-project-internal'.
           (and prj-ok-func
                (funcall prj-ok-func doctypes filepaths))
           (kill-buffer)))

       ;; Body ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       (widget-insert (format "Project Name: %s\n\n"
                              (propertize (prj-project-name)
                                          'face 'widget-field)))
       (widget-insert "Document Types (Edit) ") ;; TODO: add customizable link
       (widget-create 'push-button
                      :notify (prj-widget-checkbox-select-all prj-widget-doctypes)
                      "Select All")
       (widget-insert " ")
       (widget-create 'push-button
                      :notify (prj-widget-checkbox-deselect-all prj-widget-doctypes)
                      "Deselect All")
       (widget-insert " :\n")
       ;; Widget for doctypes.
       (let (wid)
         (dolist (doctype prj-document-types)
           (setq wid (widget-create 'checkbox
                                    :data doctype
                                    :format (concat "%[%v%] "
                                                    (prj-format-doctype doctype)
                                                    "\n")
                                    :value (and (lax-plist-get (prj-project-doctypes)
                                                               (car doctype))
                                                t))
                 prj-widget-doctypes (append prj-widget-doctypes
                                              `(,wid)))))
       (widget-insert "\n")
       (widget-insert "Include Path:\n")
       ;; Widget for filepaths.
       (setq prj-widget-filepaths
             (widget-create 'editable-list
                            :entry-format "%i %d path: %v"
                            :value (copy-list (prj-project-filepaths))
                            '(editable-field :company prj-browse-file-backend)))))
    (:hide
     (and (get-buffer "*Edit Project*")
          (kill-buffer "*Edit Project*")))))

;;;###autoload
(defun prj-find-file-frontend (command &optional ok)
  (case command
    (:show
     (let* ((filedb (prj-import-data (prj-filedb-path)))
            filelist)
       (while filedb
         (setq filelist (append filelist (cadr filedb))
               filedb (cddr filedb)))
       ;; TOOD: use `sos-source-buffer' and new implementation.
       ;; call `find-file-begin' -> `find-file'.
       (funcall ok (ido-completing-read (format "[%s] Find file: "
                                                (prj-project-name))
                                        filelist))))))

;;;###autoload
(defun prj-search-project-widget-frontend (command &optional ok)
  (case command
    (:show
     (prj-with-widget "*Search Project*"
       ;; Ok implementation callback ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       ok

       ;; Ok notify ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       (lambda (&rest ignore)
         (unless prj-widget-textfield
           (error (format "[%s] Please enter something for searching!" (prj-widget-textfield))))
         (unless (> (length prj-tmp-list1) 0)
           (error (format "[%s] Please select document types for searching!" (prj-widget-textfield))))
         (kill-buffer)
         (prj-search-project-internal prj-widget-textfield prj-tmp-list1))

       ;; Body ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       (widget-create 'editable-field
                      :format "Search: %v"
                      :value (or search "")
                      :notify (prj-widget-common-notify prj-widget-textfield)
                      :company 'prj-search-backend)
       (widget-insert "\n")
       (widget-insert "Document Types ")
       (widget-create 'push-button
                      :notify (lambda (&rest ignore)
                                (setq prj-tmp-list1 nil)
                                (dolist (box prj-widget-doctypes)
                                  (widget-value-set box t))
                                (dolist (type (prj-project-doctypes))
                                  (push type prj-tmp-list1)))
                      "Select All")
       (widget-insert " ")
       (widget-create 'push-button
                      :notify (lambda (&rest ignore)
                                (setq prj-tmp-list1 nil)
                                (dolist (box prj-widget-doctypes)
                                  (widget-value-set box nil)))
                      "Deselect All")
       (widget-insert " :\n")
       (dolist (type (prj-project-doctypes))
         (let (wid)
           (setq wid (widget-create 'checkbox
                                    :format (concat "%[%v%] " (prj-format-doctype type) "\n")
                                    :value t
                                    :notify (prj-widget-checkbox-notify :doctypes prj-tmp-list1)))
           (widget-put wid :doctypes type)
           (push wid prj-widget-doctypes)))))
    (:hide
     (and (get-buffer "*Search Project*")
          (kill-buffer "*Search Project*")))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmacro prj-with-widget (name ok-callback ok-notify &rest body)
  (declare (indent 1) (debug t))
  `(progn
     (switch-to-buffer (get-buffer-create ,name))
     ;; TODO: fix compatibility with `company'.
     ;; Face
     ;; (setq-local widget-button-face custom-button)
     ;; (setq-local widget-button-pressed-face custom-button-pressed)
     ;; (setq-local widget-mouse-face custom-button-mouse)
     ;; When possible, use relief for buttons, not bracketing.
     ;; (when custom-raised-buttons
     ;;   (setq-local widget-push-button-prefix " ")
     ;;   (setq-local widget-push-button-suffix " ")
     ;;   (setq-local widget-link-prefix "")
     ;;   (setq-local widget-link-suffix ""))
     (setq prj-ok-func ,ok-callback
           header-line-format '((:eval (format "  %s"
                                               (propertize ,name
                                                           'face 'bold)))
                                " | "
                                (:eval (format "%s or %s to jump among widgets."
                                               (propertize " TAB "
                                                           'face 'tooltip)
                                               (propertize " Shift-TAB "
                                                           'face 'tooltip)))))
     (widget-insert "\n")
     ;; ==> body
     ,@body
     ;; <=======
     (widget-insert "\n")
     (widget-create 'push-button
                    :notify ,ok-notify
                    "ok")
     (widget-insert " ")
     (widget-create 'push-button
                    :notify (lambda (&rest ignore)
                              (kill-buffer))
                    "cancel")
     ;; Make some TAB do something before its original task.
     (add-hook 'widget-forward-hook 'prj-widget-forward-or-company t t)
     (use-local-map widget-keymap)
     (widget-setup)
     ;; Move point to 1st editable-field.
     (let ((field (car widget-field-list)))
       (when field
         (goto-char (widget-field-end field))))
     ;; Enable specific feature.
     (when (featurep 'company)
       (company-mode)
       (make-local-variable 'company-backends)
       (add-to-list 'company-backends 'prj-browse-file-backend)
       (add-to-list 'company-backends 'prj-search-backend))))

(defmacro prj-widget-checkbox-select-all (checkboxes)
  `(lambda (&rest ignore)
     (dolist (box ,checkboxes)
       (widget-value-set box t))))

(defmacro prj-widget-checkbox-deselect-all (checkboxes)
  `(lambda (&rest ignore)
     (dolist (box ,checkboxes)
       (widget-value-set box nil))))

(defun prj-format-doctype (doctype)
  (format "%s (%s)" (car doctype) (cdr doctype)))

(defun prj-widget-doctypes ()
  "Return a plist of selected document types."
  (let (doctypes)
    (dolist (checkbox prj-widget-doctypes)
      (let ((doctype (and (widget-value checkbox)
                          (widget-get checkbox :data))))
        (when doctype
          (setq doctypes (append doctypes
                                 `(,(car doctype) ,(cdr doctype)))))))
    doctypes))

(defun prj-widget-filepaths ()
  "Return a list of file paths."
  (let (filepaths)
    (dolist (file (widget-value prj-widget-filepaths))
      (when (and (> (length file) 2)
                 (file-exists-p file))
        (setq filepaths (append filepaths
                                `(,(expand-file-name file))))))
    filepaths))

(defun prj-widget-checkboxes ()
  (let (ret)
    (dolist (checkbox prj-widget-checkboxes)
      (let ((data (and (widget-value checkbox)
                       (widget-get checkbox :data))))
        (when data
          (setq ret (append ret `(,data))))))
    ret))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; back-ends for `company' ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;###autoload
(defun prj-browse-file-backend (command &optional arg &rest ign)
  "The backend based on `company' to provide convenience when browsing files."
  (case command
    (prefix (prj-common-prefix 'prj-browse-file-backend))
    (candidates (prj-browse-file-complete arg))
    (ignore-case t)))

;;;###autoload
(defun prj-search-backend (command &optional arg &rest ign)
  "Following are for `company' when searching project."
  (case command
    (prefix (prj-common-prefix 'prj-search-backend))
    (candidates (prj-search-complete arg))
    (ignore-case t)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar prj-browse-file-cache nil
  "Storing (DIR . (CANDIDATES...)) for completion.")
(make-variable-buffer-local 'prj-browse-file-cache)

(defun prj-concat-filepath (dir file)
  "Return a full path combined with `dir' and `file'. It saves you the worry of whether to append '/' or not."
  (concat dir
          (unless (eq (aref dir (1- (length dir))) ?/) "/")
          file))

(defun prj-directory-files (dir &optional exclude)
  "Return a list containing file names under `dir' but exlcudes files that match `exclude'."
  (let (files)
    (dolist (file (directory-files dir))
      (and (not (member file '("." "..")))
           (not (string-match exclude file))
           (setq files (cons file files))))
    (setq files (reverse files))))

(defun prj-to-regexp (wildcardexp)
  "Translate wildcard expression to Emacs regular expression."
  (let (regexp)
    (dolist (el (split-string wildcardexp ";"))
      (cond
       ;; ex: *.el
       ((string-match "^\\*\\..+" el)
        (setq el (replace-regexp-in-string "^\\*\\." ".*\\\\." el)
              el (concat el "$")))
       ;; ex: cache-*
       ((string-match ".+\\*$" el)
        (setq el (concat "^" el)
              el (replace-regexp-in-string "\\*" ".*" el)))
       ;; ex: ABC*DEF
       ((string-match ".+\\*.+" el)
        (setq el (concat "^" el)
              el (replace-regexp-in-string "\\*" ".*" el)
              el (concat el "$")))
       ;; ex: .git or .svn
       ((string-match "\\." el)
        (setq el (replace-regexp-in-string "\\." "\\\\." el))))
      (setq regexp (concat regexp el "\\|")))
    (setq regexp (replace-regexp-in-string "\\\\|$" "" regexp)
          regexp (concat "\\(" regexp "\\)"))))

(defun prj-widget-forward-or-company ()
  "It is for `widget-forward-hook' to continue forward to next widget or show company prompt."
  (interactive)
  (and (or (prj-common-prefix 'prj-browse-file-backend)
           (prj-common-prefix 'prj-search-backend))
       (company-complete)
       (top-level)))

(defun prj-common-prefix (backend)
  "The function responds 'prefix for `prj-browse-file-backend'. Return nil means skip this backend function; Any string means there're candidates should be prompt. Only the editable-field with :file-browse property is allowed."
  (let* ((field (widget-field-at (point)))
         (field-backend (and field
                             (widget-get field :company))))
    (if (and field field-backend
             (eq field-backend backend))
        (let* ((start (widget-field-start field))
               (end (widget-field-end field))
               (prefix (buffer-substring-no-properties start end)))
          prefix)
      nil)))

(defun prj-browse-file-complete (prefix)
  "The function responds 'candiates for `prj-browse-file-backend'."
  (let* ((dir (or (and (file-directory-p prefix)
                       prefix)
                  (file-name-directory prefix)))
         path
         candidates
         directories)
    (and dir
         (unless (equal dir (car prj-browse-file-cache))
           (dolist (file (prj-directory-files dir (prj-to-regexp prj-exclude-types)))
             (setq path (prj-concat-filepath dir file))
             (push path candidates)
             ;; Add one level of children.
             (when (file-directory-p path)
               (push path directories)))
           (dolist (directory (reverse directories))
             (ignore-errors
               (dolist (child (prj-directory-files directory (prj-to-regexp prj-exclude-types)))
                 (setq path (prj-concat-filepath directory child))
                 (push path candidates))))
           (setq prj-browse-file-cache (cons dir (nreverse candidates)))))
    (all-completions prefix
                     (cdr prj-browse-file-cache))))

(defun prj-search-complete (prefix)
  "The function responds 'candiates for `prj-search-backend'."
  ;; TODO: use `prj-search-cache'.
  (all-completions prefix (prj-search-cache)))

(provide 'prj-widget-frontend)
