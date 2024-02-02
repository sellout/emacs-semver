;;; semver.el --- Semantic versioning library  -*- lexical-binding: t; -*-

;; Author: Greg Pfeil <greg@technomadic.org>
;; Maintainer: Greg Pfeil <greg@technomadic.org>
;; Package-Requires: ((emacs "27.1"))
;; URL: https://github.com/sellout/emacs-semver
;; URL: https://semver.org/
;; Version: 0.1.0

;;; Commentary:

;; Manipulate and compare Semantic Versions.

;;; Code:

(require 'eieio)

(defun semver--numeric-identifier-p (value)
  "Return non-nil if VALUE is a non-negative integer."
  (cl-typep value '(integer 0 *)))

(defun semver--alphanumeric-identifier-p (value)
  "Return non-nil if VALUE is a valid alphanumeric identifier.
Currently this only checks that it’s a string, but it should be [0-9A-Za-z-]+
and must contain at least one non-digit character.."
  (cl-typep value 'string))

(defun semver--pre-release-identifier-p (value)
  "Return non-nil if VALUE is a valid pre-release identifier."
  (or (semver--alphanumeric-identifier-p value)
      (semver--numeric-identifier-p value)))

(defun semver--build-identifier-p (value)
  "Return non-nil if VALUE is a valid build-metadata identifier."
  ;; TODO: If ‘semver--alphanumeric-identifier-p’ becomes more strict, this
  ;;       should have a case to allow a string that consists of arbitrary
  ;;       digits (including leading zeros).
  (semver--alphanumeric-identifier-p value))

(defclass semver-version ()
  ((major :initarg :major :type semver--numeric-identifier)
   (minor :initarg :minor :type semver--numeric-identifier)
   (patch :initarg :patch :type semver--numeric-identifier)
   (pre-release
    :initarg :pre-release
    :initform nil
    :type (satisfies (lambda (seq)
                       (seq-every-p #'semver--pre-release-identifier-p seq))))
   (build-metadata
    :initarg :build-metadata
    :initform nil
    :type (satisfies (lambda (seq)
                       (seq-every-p #'semver--build-identifier-p seq)))))
  :documentation "SemVer 2.0.0")

(defun semver-version-string (version)
  "Return the version string denoted by this VERSION."
  (concat (number-to-string (slot-value version 'major))
          "."
          (number-to-string (slot-value version 'minor))
          "."
          (number-to-string (slot-value version 'patch))
          (let ((pr (slot-value version 'pre-release)))
            (if pr
                (concat "-"
                        (string-join
                         (mapcar (lambda (elem)
                                   (cl-etypecase elem
                                     (integer (number-to-string elem))
                                     (string elem)))
                                 pr)
                         "."))
              ""))
          (let ((bm (slot-value version 'build-metadata)))
            (if bm (concat "+" (string-join bm ".")) ""))))

(defun semver-increment-patch (version)
  "Increment the patch component of the VERSION."
  (setf (slot-value version 'patch) (1+ (slot-value version 'patch))))

(defun semver-increment-minor (version)
  "Increment the minor component of the VERSION, zeroing the patch component."
  (setf (slot-value version 'patch) 0)
  (setf (slot-value version 'minor) (1+ (slot-value version 'minor))))

(defun semver-increment-major (version)
  "Increment the major component of the VERSION, zeroing the other components."
  (setf (slot-value version 'patch) 0)
  (setf (slot-value version 'minor) 0)
  (setf (slot-value version 'major) (1+ (slot-value version 'major))))

(defun semver-decode-version-string (version)
  "Return a decode property list of VERSION."
  (let ((version-regexp
         (rx-let ((component (one-or-more (any "0-9")))
                  (identifier (one-or-more (or (any "0-9A-Za-z-")))))
           (rx string-start
               (group-n 1 component)
               "."
               (group-n 2 component)
               "."
               (group-n 3 component)
               (opt "-" (group-n 4 identifier (zero-or-more "." identifier)))
               (opt "+"
                    (group-n 5 identifier (zero-or-more "." identifier)))
               string-end))))
    (when (string-match version-regexp version)
      (semver-version
       :major (cl-parse-integer (match-string 1 version))
       :minor (cl-parse-integer (match-string 2 version))
       :patch (cl-parse-integer (match-string 3 version))
       :pre-release (when-let ((identifiers (match-string 4 version)))
                      (mapcar (lambda (elem)
                                (condition-case nil
                                    (cl-parse-integer elem)
                                  (error elem)))
                              (save-match-data
                                (split-string identifiers "\\."))))
       :build-metadata (when-let ((identifiers (match-string 5 version)))
                         (save-match-data
                           (split-string identifiers "\\.")))))))

(defun semver-maybe-decode-version-string (version)
  "Decode VERSION when it is a ‘string’.
Return it unchanged if it is already a ‘semver-version’. Error otherwise."
  (cl-etypecase version
    (semver-version version)
    (string (semver-decode-version-string version))))

(defun semver-precedence (version1 version2)
  "Return either VERSION1 or VERSION2, whichever has higher precedence.
If both versions have the same precedence, return nil."
  (cond
   ((< (slot-value version1 'major) (slot-value version2 'major)) version2)
   ((< (slot-value version2 'major) (slot-value version1 'major)) version1)
   ((< (slot-value version1 'minor) (slot-value version2 'minor)) version2)
   ((< (slot-value version2 'minor) (slot-value version1 'minor)) version1)
   ((< (slot-value version1 'patch) (slot-value version2 'patch)) version2)
   ((< (slot-value version2 'patch) (slot-value version1 'patch)) version1)
   (t
    (let ((pr1 (slot-value version1 'pre-release))
          (pr2 (slot-value version2 'pre-release)))
      (cond
       ((and pr1 (not pr2)) version2)
       ((and (not pr1) pr2) version1)
       ((and pr1 pr2)
        (or (car (remove nil
                         (cl-mapcar (lambda (ident1 ident2)
                                      (cl-etypecase ident1
                                        ((integer 0 *)
                                         (cl-etypecase ident2
                                           ((integer 0 *)
                                            (cond ((< ident1 ident2) version2)
                                                  ((< ident2 ident1) version1)))
                                           (string version2)))
                                        (string
                                         (cl-etypecase ident2
                                           ((integer 0 *) version1)
                                           (string
                                            (cond ((string< ident1 ident2)
                                                   version2)
                                                  ((string< ident2 ident1)
                                                   version1)))))))
                                    pr1
                                    pr2)))
            (cond ((< (length pr1) (length pr2)) version2)
                  ((< (length pr2) (length pr1)) version1)))))))))

;;; comparison

;; Comparison operations are defined in terms of precedence. I.e., if two
;; versions are ‘semver-=’, that doesn’t mean they are the same string, only
;; that they have the same precedence. In particular, build-metadata does not
;; affect precedence.

(defun semver< (version1 version2)
  "Return non-nil if VERSION1 has lower precedence than VERSION2."
  (equal version2 (semver-precedence version1 version2)))

(defun semver<= (version1 version2)
  "Return non-nil if VERSION1 has the same or lower precedence as VERSION2."
  (let ((prec (semver-precedence version1 version2)))
    (or (null prec) (equal version2 prec))))

(defun semver> (version1 version2)
  "Return non-nil if VERSION1 has higher precedence than VERSION2."
  (equal version1 (semver-precedence version1 version2)))

(defun semver>= (version1 version2)
  "Return non-nil if VERSION1 has the same or higher precedence as VERSION2."
  (let ((prec (semver-precedence version1 version2)))
    (or (null prec) (equal version1 prec))))

(defun semver= (version1 version2)
  "Return non-nil if VERSION1 has the same precedence as VERSION2."
  (null (semver-precedence version1 version2)))

(provide 'semver)
;;; semver.el ends here
