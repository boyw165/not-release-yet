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

(defvar prj-tmp-string nil)
(defvar prj-tmp-list1 nil)
(defvar prj-tmp-list2 nil)
(defvar prj-tmp-list3 nil)

(defmacro prj-widget-common-notify (place)
  "(Widget) Notify function for 'editable-field and 'editable-list."
  `(lambda (wid &rest ignore)
     (setq ,place (widget-value wid))))

(defmacro prj-widget-checkbox-notify (prop place)
  "(Widget) Notify function for 'checkbox."
  `(lambda (wid &rest ignore)
     (if (widget-value wid)
	 (push (widget-get wid ,prop) ,place)
       (setq ,place (delq (widget-get wid ,prop) ,place)))))

(defmacro prj-with-widget (name ok &rest body)
  (declare (indent 1) (debug t))
  `(progn
     (switch-to-buffer ,name)
     (kill-all-local-variables)
     (let ((inhibit-read-only t))
       (erase-buffer))
     (remove-overlays)
     ;; Face
     ;; (setq-local widget-documentation-face custom-documentation)
     (setq-local widget-button-face custom-button)
     (setq-local widget-button-pressed-face custom-button-pressed)
     (setq-local widget-mouse-face custom-button-mouse)
     ;; When possible, use relief for buttons, not bracketing.
     (when custom-raised-buttons
       (setq-local widget-push-button-prefix " ")
       (setq-local widget-push-button-suffix " ")
       (setq-local widget-link-prefix "")
       (setq-local widget-link-suffix ""))
     (setq show-trailing-whitespace nil)
     (setq prj-tmp-string nil)
     (setq prj-tmp-list1 nil)
     (setq prj-tmp-list2 nil)
     (setq prj-tmp-list3 nil)
     ,@body ;; <== body
     (widget-insert "\n")
     (widget-create 'push-button
		    :notify ,ok
		    "ok")
     (widget-insert " ")
     (widget-create 'push-button
		    :notify (lambda (&rest ignore)
			      (kill-buffer))
		    "cancel")
     (use-local-map widget-keymap)
     (widget-setup)))

(defmacro prj-validate-filepaths (paths)
  "Iterate the file paths in the configuration in order to discard invalid paths."
  `(let (valid-fp)
     (dolist (f ,paths)
       (let ((fp (and (file-exists-p f)
		      (expand-file-name f))))
	 (and fp
	      (push fp valid-fp))))
     (and valid-fp
	  (setq ,paths valid-fp))))

(defmacro prj-with-file (name file &rest body)
  (declare (indent 1) (debug t))
  `(let ((temp-buffer (get-buffer-create ,name)))
     (switch-to-buffer temp-buffer)
     (goto-char (point-max))
     (progn ,@body)
     (setq buffer-file-name ,file)
     (write-region nil nil ,file nil 0)))

(defun prj-setup-create-project-widget ()
  (prj-with-widget "*Create Project*"
    ;; Ok notify ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    (lambda (&rest ignore)
      (let* ((config-file-path (expand-file-name (format "%s/%s/%s"
							 prj-workspace-path
							 prj-tmp-string
							 prj-config-name)))
	     (dir (file-name-directory config-file-path)))
	;; Validate file paths.
	(prj-validate-filepaths prj-tmp-list2)
	;; Return if there is an invalid info.
	(unless (and prj-tmp-string
		     (> (length prj-tmp-list1) 0)
		     (> (length prj-tmp-list2) 0))
	  (error "[Prj] Can't create new project due to invalid information."))
	;; Prepare directory. Directory name is also the project name.
	(unless (file-directory-p dir)
	  (make-directory dir))
	;; Export configuration.
	(let ((config (prj-new-config)))
	  (puthash :name prj-tmp-string config)
	  (puthash :doctypes prj-tmp-list1 config)
	  (puthash :filepaths prj-tmp-list2 config)
	  (prj-export-data config-file-path config))
	(kill-buffer)
	(prj-load-project)))

    ;; Body ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    (widget-insert "=== Create New Project ===\n\n")
    ;; (macroexpand '(prj-widget-common-notify prj-tmp-string))
    (widget-create 'editable-field
		   :format "Project Name: %v"
		   :notify (prj-widget-common-notify prj-tmp-string))
    (widget-insert "\n")
    (widget-insert "Document Types (Edit) ") ;; TODO: add customizable link
    (widget-create 'push-button
		   :notify (lambda (&rest ignore)
			     (setq prj-tmp-list1 nil)
			     (dolist (box prj-tmp-list3)
			       (widget-value-set box t))
			     (dolist (type prj-document-types)
			       (push type prj-tmp-list1)))
		   "Select All")
    (widget-insert " ")
    (widget-create 'push-button
		   :notify (lambda (&rest ignore)
			     (setq prj-tmp-list1 nil)
			     (dolist (box prj-tmp-list3)
			       (widget-value-set box nil)))
		   "Deselect All")
    (widget-insert " :\n")
    (dolist (type prj-document-types)
      (let (wid)
	(setq wid (widget-create 'checkbox
				 :format (concat "%[%v%] " (car type) " (" (cdr type) ")\n")
				 :notify (prj-widget-checkbox-notify :doctypes prj-tmp-list1)))
	(widget-put wid :doctypes type)
	(push wid prj-tmp-list3)))
    (widget-insert "\n")
    (widget-insert "Include Path:\n")
    (widget-create 'editable-list
		   :entry-format "%i %d %v"
		   :value '("")
		   :notify (prj-widget-common-notify prj-tmp-list2)
		   '(editable-field :value ""))))

(defun prj-setup-delete-project-widget ()
  (prj-with-widget "*Delete Project*"
    ;; Ok notify ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    (lambda (&rest ignore)
      (dolist (c prj-tmp-list1)
	;; Unload current project if it is selected.
	(when (and (prj-project-p)
		   (string-equal (prj-project-name) c))
	  (prj-unload-project))
	;; Delete directory
	(delete-directory (format "%s/%s" prj-workspace-path c) t t))
      (kill-buffer)
      (message "[Prj] Delet project ...done"))

    ;; Body ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    (widget-insert "=== Delete Project ===\n\n")
    (widget-insert "Select projects to be deleted:\n")
    (let (choices)
      (dolist (f (directory-files prj-workspace-path))
	(let ((config-file (format "%s/%s/%s" prj-workspace-path f prj-config-name)))
	  (when (file-exists-p config-file)
	    (push f choices))))
      (unless choices
	(kill-buffer)
	(error "[Prj] No projects can be deleted."))
      (dolist (c choices)
	(widget-put (widget-create 'checkbox
				   :format (concat "%[%v%] " c "\n")
				   :notify (prj-widget-checkbox-notify :filepaths prj-tmp-list1))
		    :filepaths c)))))

(defun prj-setup-edit-project-widget ()
  (prj-with-widget "*Edit Project*"
    ;; Ok notify ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    (lambda (&rest ignore)
      ;; Validate file paths.
      (prj-validate-filepaths prj-tmp-list2)
      ;; Export configuration.
      (puthash :doctypes prj-tmp-list1 prj-config)
      (puthash :filepaths prj-tmp-list2 prj-config)
      (prj-export-data (prj-config-path) prj-config)
      (kill-buffer))

    ;; Body ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    (setq prj-tmp-list1 (gethash :doctypes prj-config))
    (setq prj-tmp-list2 (gethash :filepaths prj-config))
    (widget-insert "=== Edit Project ===\n\n")
    (widget-insert (format "Project Name: %s\n\n" (prj-project-name)))
    (widget-insert "Document Types (Edit) ") ;; TODO: add customizable link
    (widget-create 'push-button
		   :notify (lambda (&rest ignore)
			     (setq prj-tmp-list1 nil)
			     (dolist (box prj-tmp-list3)
			       (widget-value-set box t))
			     (dolist (type prj-document-types)
			       (push type prj-tmp-list1)))
		   "Select All")
    (widget-insert " ")
    (widget-create 'push-button
		   :notify (lambda (&rest ignore)
			     (setq prj-tmp-list1 nil)
			     (dolist (box prj-tmp-list3)
			       (widget-value-set box nil)))
		   "Deselect All")
    (widget-insert " :\n")
    (dolist (type prj-document-types)
      (let (wid)
	(setq wid (widget-create 'checkbox
				 :format (concat "%[%v%] " (car type) " (" (cdr type) ")\n")
				 :value (let (res)
					  (dolist (currtype (gethash :doctypes prj-config))
					    (if (string-equal (car currtype) (car type))
						(setq res t)))
					  res)
				 :notify (prj-widget-checkbox-notify :doctypes prj-tmp-list1)))
	(widget-put wid :doctypes type)
	(push wid prj-tmp-list3)))
    (widget-insert "\n")
    (widget-insert "Include Path:\n")
    (widget-create 'editable-list
		   :entry-format "%i %d %v"
		   :value (gethash :filepaths prj-config)
		   :notify (prj-widget-common-notify prj-tmp-list2)
		   '(editable-field))))

(defun prj-setup-search-project-widget ()
  (prj-with-widget "*Search Project*"
    ;; Ok notify ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    (lambda (&rest ignore)
      (unless prj-tmp-string
	(error (format "[%s] Please enter something for searching!" (prj-project-name))))
      (unless (> (length prj-tmp-list1) 0)
	(error (format "[%s] Please select document types for searching!" (prj-project-name))))
      (kill-buffer)
      (prj-with-file "*Search*" (prj-searchdb-path)
	(insert (format ">>> %s\n" prj-tmp-string))
	(dolist (f (prj-import-data (prj-filedb-path)))
	  (message "[%s] Searching ...%s" (prj-project-name) f)
	  (goto-char (point-max))
	  (call-process "grep" nil (list (current-buffer) nil) t "-nH" prj-tmp-string f))
	(insert "<<<\n\n"))
      (message (format "[%s] Search ...done" (prj-project-name))))

    ;; Body ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    (setq prj-tmp-list1 (prj-project-doctypes))
    (widget-insert "=== Search Project ===\n\n")
    (widget-create 'editable-field
		   :format "Search: %v"
		   :notify (prj-widget-common-notify prj-tmp-string))
    (widget-insert "\n")
    (widget-insert "Document Types ")
    (widget-create 'push-button
		   :notify (lambda (&rest ignore)
			     (setq prj-tmp-list1 nil)
			     (dolist (box prj-tmp-list3)
			       (widget-value-set box t))
			     (dolist (type prj-document-types)
			       (push type prj-tmp-list1)))
		   "Select All")
    (widget-insert " ")
    (widget-create 'push-button
		   :notify (lambda (&rest ignore)
			     (setq prj-tmp-list1 nil)
			     (dolist (box prj-tmp-list3)
			       (widget-value-set box nil)))
		   "Deselect All")
    (widget-insert " :\n")
    (dolist (type (prj-project-doctypes))
      (let (wid)
	(setq wid (widget-create 'checkbox
				 :format (concat "%[%v%] " (car type) " (" (cdr type) ")\n")
				 :value t
				 :notify (prj-widget-checkbox-notify :doctypes prj-tmp-list1)))
	(widget-put wid :doctypes type)
	(push wid prj-tmp-list3)))))

(provide 'prj-widget)
