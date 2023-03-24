;; -*- lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(require 'buttercup)
(require 'semver)

(describe "serialization"
  (it "decodes empty version"
    (expect (semver-version-string (semver-version :major 0 :minor 0 :patch 0))
            :to-equal
            "0.0.0"))
  (it "decodes initial release"
    (expect (semver-version-string (semver-version :major 1 :minor 0 :patch 0))
            :to-equal
            "1.0.0"))
  (it "decodes alphabetical pre-release"
    (expect (semver-version-string (semver-version :major 1 :minor 0 :patch 0 :pre-release '("beta")))
            :to-equal
            "1.0.0-beta"))
  (it "decodes numeric pre-release"
    (expect (semver-version-string (semver-version :major 1 :minor 0 :patch 0 :pre-release '(7)))
            :to-equal
            "1.0.0-7"))
  (it "decodes multiple pre-release"
    (expect (semver-version-string (semver-version :major 1 :minor 0 :patch 0 :pre-release '("rc" 2)))
            :to-equal
            "1.0.0-rc.2"))
  (it "decodes alphabetical build-metadata"
    (expect (semver-version-string (semver-version :major 1 :minor 0 :patch 0 :build-metadata '("x86-64-gnu-linux")))
            :to-equal
            "1.0.0+x86-64-gnu-linux"))
  (it "decodes numeric build-metadata"
    (expect (semver-version-string (semver-version :major 1 :minor 0 :patch 0 :build-metadata '("7")))
            :to-equal
            "1.0.0+7"))
  (it "decodes multiple build-metadata"
    (expect (semver-version-string (semver-version :major 1 :minor 0 :patch 0 :build-metadata '("rc" "2")))
            :to-equal
            "1.0.0+rc.2"))
  (it "decodes pre-release with build-metadata"
    (expect (semver-version-string (semver-version :major 1
                                                   :minor 0
                                                   :patch 0
                                                   :pre-release '("alpha" 3)
                                                   :build-metadata '("x86-64-gnu-linux")))
            :to-equal
            "1.0.0-alpha.3+x86-64-gnu-linux")))

(describe "parsing"
  (it "decodes empty version"
    (expect (semver-decode-version-string "0.0.0")
            :to-equal
            (semver-version :major 0 :minor 0 :patch 0)))
  (it "decodes initial release"
    (expect (semver-decode-version-string "1.0.0")
            :to-equal
            (semver-version :major 1 :minor 0 :patch 0)))
  (it "decodes alphabetical pre-release"
    (expect (semver-decode-version-string "1.0.0-beta")
            :to-equal
            (semver-version :major 1 :minor 0 :patch 0 :pre-release '("beta"))))
  (it "decodes numeric pre-release"
    (expect (semver-decode-version-string "1.0.0-7")
            :to-equal
            (semver-version :major 1 :minor 0 :patch 0 :pre-release '(7))))
  (it "decodes multiple pre-release"
    (expect (semver-decode-version-string "1.0.0-rc.2")
            :to-equal
            (semver-version :major 1 :minor 0 :patch 0 :pre-release '("rc" 2))))
  (it "decodes alphabetical build-metadata"
    (expect (semver-decode-version-string "1.0.0+x86-64-gnu-linux")
            :to-equal
            (semver-version :major 1 :minor 0 :patch 0 :build-metadata '("x86-64-gnu-linux"))))
  (it "decodes numeric build-metadata"
    (expect (semver-decode-version-string "1.0.0+7")
            :to-equal
            (semver-version :major 1 :minor 0 :patch 0 :build-metadata '("7"))))
  (it "decodes multiple build-metadata"
    (expect (semver-decode-version-string "1.0.0+rc.2")
            :to-equal
            (semver-version :major 1 :minor 0 :patch 0 :build-metadata '("rc" "2"))))
  (it "decodes pre-release with build-metadata"
    (expect (semver-decode-version-string "1.0.0-alpha.3+x86-64-gnu-linux")
            :to-equal
            (semver-version :major 1
                            :minor 0
                            :patch 0
                            :pre-release '("alpha" 3)
                            :build-metadata '("x86-64-gnu-linux")))))

(describe "incrementing"
  (it "increments patch from 0.0.0"
    (expect (let ((version (semver-decode-version-string "0.0.0")))
              (semver-increment-patch version)
              version)
            :to-equal
            (semver-decode-version-string "0.0.1")))
  (it "increments minor from 0.0.0"
    (expect (let ((version (semver-decode-version-string "0.0.0")))
              (semver-increment-minor version)
              version)
            :to-equal
            (semver-decode-version-string "0.1.0")))
  (it "increments major from 0.0.0"
    (expect (let ((version (semver-decode-version-string "0.0.0")))
              (semver-increment-major version)
              version)
            :to-equal
            (semver-decode-version-string "1.0.0")))
  (it "increments patch from arbitrary version"
    (expect (let ((version (semver-decode-version-string "6.18.66")))
              (semver-increment-patch version)
              version)
            :to-equal
            (semver-decode-version-string "6.18.67")))
  (it "increments minor from arbitrary version"
    (expect (let ((version (semver-decode-version-string "6.18.66")))
              (semver-increment-minor version)
              version)
            :to-equal
            (semver-decode-version-string "6.19.0")))
  (it "increments major from arbitrary version"
    (expect (let ((version (semver-decode-version-string "6.18.66")))
              (semver-increment-major version)
              version)
            :to-equal
            (semver-decode-version-string "7.0.0"))))

(describe "precedence"
  (it "matches the examples in the spec §11.2"
    (expect (sort (list (semver-decode-version-string "2.1.1")
                        (semver-decode-version-string "2.1.0")
                        (semver-decode-version-string "2.0.0")
                        (semver-decode-version-string "1.0.0"))
                  'semver<)
            :to-equal
            (list (semver-decode-version-string "1.0.0")
                  (semver-decode-version-string "2.0.0")
                  (semver-decode-version-string "2.1.0")
                  (semver-decode-version-string "2.1.1"))))
  (it "matches the examples in the spec §11.3"
    (expect (semver< (semver-decode-version-string "1.0.0-alpha")
                     (semver-decode-version-string "1.0.0"))))
  (it "matches the examples in the spec §11.4"
    (expect (sort (list (semver-decode-version-string "1.0.0")
                        (semver-decode-version-string "1.0.0-rc.1")
                        (semver-decode-version-string "1.0.0-beta.11")
                        (semver-decode-version-string "1.0.0-beta.2")
                        (semver-decode-version-string "1.0.0-alpha.beta")
                        (semver-decode-version-string "1.0.0-alpha.1")
                        (semver-decode-version-string "1.0.0-alpha"))
                  'semver<)
            :to-equal
            (list (semver-decode-version-string "1.0.0-alpha")
                  (semver-decode-version-string "1.0.0-alpha.1")
                  (semver-decode-version-string "1.0.0-alpha.beta")
                  (semver-decode-version-string "1.0.0-beta.2")
                  (semver-decode-version-string "1.0.0-beta.11")
                  (semver-decode-version-string "1.0.0-rc.1")
                  (semver-decode-version-string "1.0.0")))))

(provide 'semver-tests)
;;; semver-tests.el ends here
