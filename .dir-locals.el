;;; .dir-locals.el --- description -*- lexical-binding: t; -*-

((nil . ((+upload-root-remotes . (("eshua" . "/ssh:thierry@eshua:/home/thierry/temail")
                                  ("eshub" . "/ssh:thierry@eshub:/home/thierry/temail")
                                  ("eshuc" . "/ssh:thierry@eshuc:/home/thierry/temail")))
         (ssh-deploy-on-explicit-save . nil)
         (ssh-deploy-script . (lambda() (let ((default-directory ssh-deploy-root-remote))(shell-command "make all")))))))

;;; .dir-locals.el ends here
