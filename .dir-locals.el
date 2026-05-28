;;; Directory Local Variables            -*- no-byte-compile: t -*-
;;; For more information see (info "(emacs) Directory Variables")

;; lean4-mode picks up the lean-toolchain file automatically.
;; These settings keep things consistent across the project.

((lean4-mode
  . ((fill-column . 100)
     (indent-tabs-mode . nil)
     (tab-width . 2)))
 (nil
  . ((projectile-project-root . ".")
     (eval . (setq-local compile-command "lake build")))))
