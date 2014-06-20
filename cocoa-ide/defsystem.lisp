;;-*-Mode: LISP; Package: CCL -*-
;;;
;;;   Copyright (C) 2007 Clozure Associates
;;;

(in-package "CCL")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (use-interface-dir :cocoa))

;; These are used to communicate with ide-bundle, which must be loaded before objc-support.
;; They are defvar'ed so the caller can set them before loading us.
(defvar *cocoa-ide-path* nil)
(defvar *cocoa-ide-copy-headers-p* nil)
(require "IDE-BUNDLE")

(require "OBJC-SUPPORT")

(defpackage "GUI"
  (:use :common-lisp :ccl)
  (:import-from
   "CCL"
   ;; symbols defined here
   *cocoa-ide-path*
   *cocoa-ide-copy-headers-p*
   load-ide
   build-ide
   ;; Misc symbols that perhaps should be exported from CCL but currently aren't.
   report-bad-arg
   native-translated-namestring
   make-id-map
   assign-id-map-id
   id-map-free-object
   process-thread
   process-serial-number
   ensure-directory-pathname
   recursive-copy-directory
   application
   ;; Symbols that perhaps should be exported by ObjC support but aren't
   @selector
   *nsapp*
   with-nsstr
   %make-nsstring
   lisp-string-from-nsstring
   with-autorelease-pool
   ns-height
   ns-width
   *cocoa-event-process*
   create-autorelease-pool
   release-autorelease-pool
   release-canonical-nsobject
   objc-message-send
   open-main-bundle
   )
  (:export
   "ABSTRACT-NS-LISP-STRING"
   "NS-LISP-STRING"
   "NS-LISP-STRING-STRING"
   "BACKGROUND-PROCESS-RUN-FUNCTION"

   "EXECUTE-IN-GUI"
   ))

(defparameter *ide-lib-files*
  '("libdispatch"
    "event-process"
    "cg"
    "cf-utils"))

(defparameter *ide-files*
  '(;"ide-bundle" - loaded by hand above
    "constants"
    "cocoa-utils"
    "cocoa-defaults"
    "cocoa-typeout"
    "console-window"
    "console-log"
    "cocoa-window"
    "cocoa-doc"
    "compile-hemlock"
    "hemlock"  ;; treated specially below, compile-hemlock must come before.
    "cocoa-editor"
    "cocoa-listener"
    "cocoa-grep"
    "cocoa-backtrace"
    "inspector"
    "project"
    "cocoa-remote-lisp"
    "preferences-views"
    "preferences"
    "processes-window"
    "apropos-window"
    "xapropos"
    "hemlock-commands"
    "file-dialogs"
    "menus"
    "app-delegate"
    "ide-self-update"
    "search-files"
    "start"
    ))

(defparameter *leopard-only-ide-files*
  '("xinspector"
    ))

(defun load-ide-lib-files (names lib-dir force-compile)
  (let* ((bin-dir (merge-pathnames ";fasls;" lib-dir)))
    (ensure-directories-exist bin-dir)
    (with-compilation-unit ()
      (dolist (name names)
	(let* ((source (make-pathname :name name
				      :type (pathname-type *.lisp-pathname*)
				      :defaults lib-dir))
	       (fasl (make-pathname :name name
				    :type (pathname-type *.fasl-pathname*)
				    :defaults bin-dir)))
	  (when (or force-compile
		    (not (probe-file fasl))
		    (> (file-write-date source)
		       (file-write-date fasl)))
	    (compile-file source :output-file fasl :verbose t))
	  (load fasl :verbose t))))))

(defun load-ide-files (names src-dir force-compile)
  (declare (special *hemlock-files*)) ;; kludge
  (let* ((bin-dir (merge-pathnames ";fasls;" src-dir)))
    (ensure-directories-exist bin-dir)
    (with-compilation-unit ()
      (dolist (name names)
        (let* ((source (make-pathname :name name :type (pathname-type *.lisp-pathname*)
                                      :defaults src-dir))
               (fasl (make-pathname :name name :type (pathname-type *.fasl-pathname*)
                                    :defaults bin-dir))
               (sources (cons source
                              (and (equalp name "hemlock")
                                   ;; This is defined in compile-hemlock, which is loaded first
                                   (mapcar #'hemlock-source-pathname *hemlock-files*)))))
          (if (needs-compile-p fasl sources force-compile)
            (progn
              ;; Once compile something, keep compiling, in case macros changed.
              (setq force-compile t)
              (compile-file source :output-file fasl :verbose t :load t))
            (load fasl :verbose t))))))
  force-compile)

(defun load-ide (&optional force-compile)
  ;; kludge to limit experimental files to Leopard
  #+darwin-target
  (rlet ((p :int))
    (#_Gestalt #$gestaltSystemVersion p)
    (when (>= (%get-long p) #x1050)
      (setq *ide-files* (append *ide-files* *leopard-only-ide-files*))))
  (load-ide-lib-files *ide-lib-files* "ccl:cocoa-ide;lib;" force-compile)
  (load-ide-files *ide-files* "ccl:cocoa-ide;" force-compile)
  (provide "COCOA"))
