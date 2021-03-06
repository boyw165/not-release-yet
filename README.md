## Usage
Add following script in your .emacs file.
```
;; Automaticall add all the sub-directories to load-path.
(defun update-loadpath (base exclude)
  "Add sub-directories recursively to `load-path'.
The `base' should be a directory string and the `exclude' should be a list that to be skipped."
  (dolist (f (directory-files base))
    (let ((name (concat base "/" f)))
      (when (and (file-directory-p name)
                 (not (member f exclude)))
        (update-loadpath name exclude)
        )
      )
    )
  (add-to-list 'load-path base)
  )
(update-loadpath "~/.emacs.d" '("." ".." ".svn" ".git"))

;; Enable `oops-mode'.
(require 'oops)
(oops-mode 1)
```

This is my .emacs setting.
```
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(column-number-mode t)
 '(cua-mode t nil (cua-base))
 '(global-hl-line-mode t)
 '(global-linum-mode t)
 '(highlight-symbol-colors (quote ("yellow" "cyan" "SpringGreen1" "moccasin" "violet")))
 '(imenu-sort-function (quote imenu--sort-by-name))
 '(package-archives (quote (("gnu" . "http://elpa.gnu.org/packages/") ("elpa" . "http://melpa.milkbox.net/packages/") ("marmalade" . "http://marmalade-repo.org/packages/"))))
 '(show-paren-mode nil)
 '(vc-handled-backends nil)
 '(which-function-mode t))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

;; Automaticall add all the sub-directories to load-path.
(defun update-loadpath (base exclude)
  "Add sub-directories recursively to `load-path'.
The `base' should be a directory string and the `exclude' should be a list that to be skipped."
  (dolist (f (directory-files base))
    (let ((name (concat base "/" f)))
      (when (and (file-directory-p name)
                 (not (member f exclude)))
        (update-loadpath name exclude)
        )
      )
    )
  (add-to-list 'load-path base)
  )
(update-loadpath "~/.emacs.d" '("." ".." ".svn" ".git"))

;; Enable `oops-mode'.
(require 'oops)
(oops-mode 1)
```

## TODO List
* ~~Folk `hl-param` to my repo, `hl-anything`.~~
* ~~Merge `hl-symb` into `hl-anything`.~~
* ~~Write `history.el` to support generic history design.~~
* Refer to `helm-projectile` to implement project management and workspace concept.
* Design a multiple help window framework in `oops-win-mode.el`.
* Create a multiple help buffer framework in `oops-help-buffer.el`.
* Use `helm` to implement multiple help mechanism.
* Try to use hook mechanism to make strategy pattern (refer `to company`).
* Is this feature a mode or a framework? Maybe use `(oops-framework 1)` is better.
* Add copyright.
* Enhance `hl-anything`, make it flexibly support more languages.
