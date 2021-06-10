;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(uiop:define-package :nyxt/web-mode
  (:use :common-lisp :trivia :nyxt)
  (:import-from #:keymap #:define-key #:define-scheme)
  (:import-from #:class-star #:define-class)
  (:documentation "Mode for web pages"))
(in-package :nyxt/web-mode)
(eval-when (:compile-toplevel :load-toplevel :execute)
  (trivial-package-local-nicknames:add-package-local-nickname :alex :alexandria)
  (trivial-package-local-nicknames:add-package-local-nickname :sera :serapeum))

;; TODO: Remove web-mode from special buffers (e.g. help).
;; This is required because special buffers cannot be part of a history (and it breaks it).
;; Bind C-l to set-url-new-buffer?  Wait: What if we click on a link?  url
;; changes in special buffers should open a new one.
;; Or else we require that all special-buffer-generating commands open a new buffer.

(define-mode web-mode ()
  "Base mode for interacting with documents."
  ((rememberable-p nil)
   (history-blocklist '("https://duckduckgo.com/l/")
                      ;; TODO: Find a more automated way to do it.  WebKitGTK
                      ;; automatically removes such redirections from its
                      ;; history.  How?
                      :type list-of-strings
                      :documentation "URL prefixes to not save in history.
Example: DuckDuckGo redirections should be ignored or else going backward in
history after consulting a result reloads the result, not the duckduckgo
search.")
   (conservative-history-movement-p
    nil
    :type boolean
    :documentation "Whether history navigation is restricted by buffer-local history.")
   (box-style (cl-css:css
               '((".nyxt-hint"
                  :background "rgba(120,120,120,0.80)"
                  :color "white"
                  :font-weight "bold"
                  :padding "0px 3px 0px 3px"
                  :border-radius "2px"
                  :z-index #.(1- (expt 2 31)))))
              :documentation "The style of the boxes, e.g. link hints.")
   (highlighted-box-style (cl-css:css
                           '((".nyxt-hint.nyxt-highlight-hint"
                              :background "#37a8e4")))
                          :documentation "The style of highlighted boxes, e.g. link hints.")
   (hints-alphabet "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                   :type string
                   :documentation "The alphabet (charset) to use for hints.
Order matters -- the ones that go first are more likely to appear more often
and to index the top of the page.")
   (keymap-scheme
    (define-scheme "web"
      scheme:cua
      (list
       "C-M-right" 'history-forwards-all-query
       "C-M-left" 'history-all-query
       "C-shift-h" 'history-all-query
       "C-shift-H" 'history-all-query
       "M-shift-right" 'history-forwards-query
       "M-shift-left" 'history-backwards-query
       "M-right" 'history-forwards
       "M-left" 'history-backwards
       "M-]" 'history-forwards
       "M-[" 'history-backwards
       "M-i" 'focus-first-input-field
       "C-j" 'follow-hint
       "C-u C-j" 'follow-hint-new-buffer-focus
       "C-J" 'follow-hint-new-buffer
       "C-M-j" 'follow-hint-nosave-buffer-focus
       "C-u C-M-j" 'follow-hint-nosave-buffer
       "C-x C-w" 'copy-hint-url
       "C-c" 'copy
       "button9" 'history-forwards
       "button8" 'history-backwards
       "C-+" 'zoom-page
       "C-=" 'zoom-page              ; Because + shifted = on QWERTY.
       "C-hyphen" 'unzoom-page
       "C-0" 'reset-page-zoom
       "C-button4" 'zoom-page
       "C-button5" 'unzoom-page
       "C-M-c" 'open-inspector
       "C-m g" 'bookmark-hint
       "C-f" 'search-buffer
       "f3" 'search-buffer
       "M-f" 'remove-search-hints
       "C-." 'jump-to-heading
       "end" 'maybe-scroll-to-bottom
       "home" 'maybe-scroll-to-top
       "C-down" 'scroll-to-bottom
       "C-up" 'scroll-to-top
       "C-i" 'autofill
       "C-c '" 'edit-with-external-editor
       ;; Leave SPACE and arrow keys unbound so that the renderer decides whether to
       ;; navigate textboxes (arrows), insert or scroll (space).
       "pageup" 'scroll-page-up
       "pagedown" 'scroll-page-down
       "pageend" 'scroll-to-bottom
       "pagehome" 'scroll-to-top
       ;; keypad, gtk:
       "keypadleft" 'scroll-left
       "keypaddown" 'scroll-down
       "keypadup" 'scroll-up
       "keypadright" 'scroll-right
       "keypadend" 'scroll-to-bottom
       "keypadhome" 'scroll-to-top
       "keypadnext" 'scroll-page-down
       "keypadpageup" 'scroll-page-up
       "keypadprior" 'scroll-page-up)
      scheme:emacs
      (list
       "C-M-f" 'history-forwards-all-query
       "C-M-b" 'history-all-query
       "M-f" 'history-forwards-query
       "M-b" 'history-backwards-query
       "C-f" 'history-forwards
       "C-b" 'history-backwards
       "C-g" 'noop                      ; Emacs users may hit C-g out of habit.
       "M-g M-g" 'follow-hint           ; Corresponds to Emacs' `goto-line'.
       "M-g g" 'follow-hint-new-buffer-focus
       "C-u M-g M-g" 'follow-hint-new-buffer
       "C-u M-g g" 'follow-hint-new-buffer
       "C-M-g C-M-g" 'follow-hint-nosave-buffer-focus
       "C-M-g g" 'follow-hint-nosave-buffer
       "C-x C-w" 'copy-hint-url
       "C-y" 'paste
       "M-w" 'copy
       "button9" 'history-forwards
       "button8" 'history-backwards
       "C-p" 'scroll-up
       "C-n" 'scroll-down
       "C-x C-+" 'zoom-page
       "C-x C-=" 'zoom-page ; Because + shifted = on QWERTY.
       "C-x C-hyphen" 'unzoom-page
       "C-x C-0" 'reset-page-zoom
       "C-m g" 'bookmark-hint
       "C-s s" 'search-buffer
       "C-s k" 'remove-search-hints
       "C-." 'jump-to-heading
       "M-s->" 'scroll-to-bottom
       "M-s-<" 'scroll-to-top
       "M->" 'scroll-to-bottom
       "M-<" 'scroll-to-top
       "C-v" 'scroll-page-down
       "M-v" 'scroll-page-up)

      scheme:vi-normal
      (list
       "H" 'history-backwards
       "L" 'history-forwards
       "M-h" 'history-backwards-query
       "M-l" 'history-forwards-query
       "M-H" 'history-all-query
       "M-L" 'history-forwards-all-query
       "f" 'follow-hint
       "F" 'follow-hint-new-buffer-focus
       "; f" 'follow-hint-new-buffer
       "g f" 'follow-hint-nosave-buffer
       "g F" 'follow-hint-nosave-buffer-focus
       "button9" 'history-forwards
       "button8" 'history-backwards
       "+" 'zoom-page
       "hyphen" 'unzoom-page
       "0" 'reset-page-zoom
       "z i" 'zoom-page
       "z o" 'unzoom-page
       "z z" 'reset-page-zoom
       "g h" 'jump-to-heading
       "g H" 'jump-to-heading-buffers
       "/" 'search-buffer
       "?" 'remove-search-hints
       "m f" 'bookmark-hint
       "h" 'scroll-left
       "j" 'scroll-down
       "k" 'scroll-up
       "l" 'scroll-right
       "G" 'scroll-to-bottom
       "g g" 'scroll-to-top
       "C-f" 'scroll-page-down
       "C-b" 'scroll-page-up
       "space" 'scroll-page-down
       "s-space" 'scroll-page-up
       "pageup" 'scroll-page-up
       "pagedown" 'scroll-page-down)))))

(sera:export-always '%clicked-in-input?)
(define-parenscript %clicked-in-input? ()
  (ps:chain document active-element tag-name))

(sera:export-always 'input-tag-p)
(declaim (ftype (function ((or string null)) boolean) input-tag-p))
(defun input-tag-p (tag)
  (or (string= tag "INPUT")
      (string= tag "TEXTAREA")))

(defun call-non-input-command-or-forward (command &key (buffer (current-buffer))
                                                    (window (current-window)))
  (let ((response (%clicked-in-input?)))
    (if (input-tag-p response)
        (ffi-generate-input-event
         window
         (nyxt::last-event buffer))
        (funcall command))))

(define-command paste-or-set-url (&optional (buffer (current-buffer)))
  "Paste text if active element is an input tag, forward event otherwise."
  (let ((response (%clicked-in-input?)))
    (let ((url-empty (url-empty-p (url-at-point buffer))))
      (if (and (input-tag-p response) url-empty)
          (funcall #'paste)
          (unless url-empty
            (make-buffer-focus :url (url-at-point buffer)
                               :nosave-buffer-p (nosave-buffer-p buffer)))))))

(define-command maybe-scroll-to-bottom (&optional (buffer (current-buffer)))
  "Scroll to bottom if no input element is active, forward event otherwise."
  (call-non-input-command-or-forward #'scroll-to-bottom :buffer buffer))

(define-command maybe-scroll-to-top (&optional (buffer (current-buffer)))
  "Scroll to top if no input element is active, forward event otherwise."
  (call-non-input-command-or-forward #'scroll-to-top :buffer buffer))

(defun load-history-url (url-or-node
                         &key (buffer (current-buffer))
                              (message "History entry is already the current URL."))
  "Go to HISTORY-NODE's URL."
  (unless (quri:uri-p url-or-node)
    (setf url-or-node (url (htree:data url-or-node))))
  (if (quri:uri= url-or-node (url buffer))
      (echo message)
      (buffer-load url-or-node)))

(define-command history-backwards (&optional (buffer (current-buffer)))
  "Go to parent URL in history."
  (let ((new-node
          (with-data-access (history (history-path buffer))
            (if (conservative-history-movement-p (find-mode buffer 'web-mode))
                (htree:backward-owned-parents history)
                (htree:backward history))
            (htree:current-owner-node history))))
    (load-history-url new-node
                      :message "No backward history.")))

(define-command history-forwards (&optional (buffer (current-buffer)))
  "Go to forward URL in history."
  (let ((new-node
          (with-data-access (history (history-path buffer))
            (htree:forward history)
            (htree:current-owner-node history))))
    (load-history-url new-node
                      :message "No forward history.")))

(define-class history-backwards-source (prompter:source)
  ((prompter:name "Parent URLs")
   (buffer :initarg :buffer :accessor buffer :initform nil)
   (prompter:constructor
    (lambda (source)
      (with-data-unsafe (history (history-path (buffer source)))
        (funcall (if (conservative-history-movement-p (find-mode (buffer source) 'web-mode))
                     #'htree:all-contiguous-owned-parents
                     #'htree:all-parents)
                 history)))))
  (:export-class-name-p t))
(define-user-class history-backwards-source)

(defmethod prompter:object-attributes ((node history-tree:node))
  (let ((entry (htree:data (history-tree:entry node))))
    `(("URL" ,(render-url (url entry)))
      ("Title" ,(title entry)))))

(define-command history-backwards-query (&optional (buffer (current-buffer)))
  "Query parent URL to navigate back to."
  (let ((input (first (prompt
                       :prompt "Navigate backwards to"
                       :sources (make-instance 'user-history-backwards-source
                                               :buffer buffer)))))
    (when input
      (with-data-access (history (history-path buffer))
        (loop until (eq input (htree:current-owner-node history))
              do (htree:backward history)))
      (load-history-url input))))

(define-class direct-history-forwards-source (prompter:source)
  ((prompter:name "First child of all forward-branches")
   (buffer :initarg :buffer :accessor buffer :initform nil)
   (prompter:constructor
    (lambda (source)
      (with-data-unsafe (history (history-path (buffer source)))
        (funcall (if (conservative-history-movement-p (find-mode (buffer source) 'web-mode))
                     (alex:compose #'htree:owned-children #'htree:current-owner)
                     (alex:compose #'htree:children #'htree:current-owner-node))
                 history)))))
  (:documentation "Direct children of the current history node.")
  (:export-class-name-p t))
(define-user-class direct-history-forwards-source)

(define-command history-forwards-direct-children (&optional (buffer (current-buffer)))
  "Query child URL to navigate to."
  (let ((input (first (prompt
                       :prompt "Navigate forwards to"
                       :sources (make-instance 'user-direct-history-forwards-source
                                               :buffer buffer)))))
    (when input
      (with-data-access (history (history-path buffer))
        (htree:go-to-child (htree:data input) history))
      (load-history-url input))))

(define-command history-forwards-maybe-query (&optional (buffer (current-buffer)))
  "If current node has multiple children, query which one to navigate to.
Otherwise go forward to the only child."
  (with-data-unsafe (history (history-path buffer))
    (if (<= 2 (length
               (if (conservative-history-movement-p (find-mode buffer 'web-mode))
                   (htree:owned-children (htree:current-owner history))
                   (htree:children (htree:current-owner-node history)))))
        (history-forwards-direct-children)
        (history-forwards))))

(define-class history-forwards-source (prompter:source)
  ((prompter:name "All children URLs of the current forward-branch")
   (buffer :initarg :buffer :accessor buffer :initform nil)
   (prompter:constructor
    (lambda (source)
      (with-data-unsafe (history (history-path (buffer source)))
        (htree:all-forward-children history)))))
  (:export-class-name-p t))
(define-user-class history-forwards-source)

(define-command history-forwards-query (&optional (buffer (current-buffer)))
  "Query forward-URL to navigate to."
  (let ((input (first (prompt
                       :prompt "Navigate forwards to"
                       :sources (list (make-instance 'user-history-forwards-source
                                                     :buffer buffer))))))
    (when input
      (with-data-access (history (history-path buffer))
        ;; REVIEW: Alternatively, we could use the COUNT argument with
        ;; (1+ (position input (htree:all-forward-children history)))
        ;; Same with `history-backwards-query'.
        (loop until (eq input (htree:current-owner-node history))
              do (htree:forward history)))
      (load-history-url input))))

(define-class all-history-forwards-source (prompter:source)
  ((prompter:name "Child URLs")
   (buffer :initarg :buffer :accessor buffer :initform nil)
   (prompter:constructor
    (lambda (source)
      (with-data-unsafe (history (history-path (buffer source)))
        (funcall (if (conservative-history-movement-p (find-mode (buffer source) 'web-mode))
                     (alex:compose #'htree:all-contiguous-owned-children #'htree:current-owner)
                     #'htree:all-children)
                 history)))))
  (:export-class-name-p t))
(define-user-class all-history-forwards-source)

(define-command history-forwards-all-query (&optional (buffer (current-buffer)))
  "Query URL to forward to, from all child branches."
  (let ((input (first (prompt
                       :prompt "Navigate forwards to (all branches)"
                       :sources (list (make-instance 'user-all-history-forwards-source
                                                     :buffer buffer))))))
    (when input
      (with-data-access (history (history-path buffer))
        (htree:forward history))
      (load-history-url input))))

(define-class history-all-source (prompter:source)
  ((prompter:name "All history URLs")
   (buffer :initarg :buffer :accessor buffer :initform nil)
   (prompter:constructor
    (lambda (source)
      (with-data-unsafe (history (history-path (buffer source)))
        (funcall (if (conservative-history-movement-p (find-mode (buffer source) 'web-mode))
                     #'htree:all-current-owner-nodes
                     #'htree:all-current-branch-nodes)
                 history)))))
  (:export-class-name-p t))
(define-user-class history-all-source)

(define-command history-all-query (&optional (buffer (current-buffer)))
  "Query URL to go to, from the whole history."
  (let ((input (prompt
                :prompt "Navigate to"
                :sources (list (make-instance 'user-history-all-source
                                              :buffer buffer)))))
    (when input
      (with-data-access (history (history-path buffer))
        (htree:visit-all history input))
      (load-history-url input))))

(defun title-or-fallback (history-entry)
  "Return HISTORY-ENTRY title or, if empty, the URL."
  (let ((title (title history-entry)))
    (if (str:emptyp title)
        (render-url (url history-entry))
        title)))

(define-command buffer-history-tree (&optional (buffer (current-buffer)))
  "Open a new buffer displaying the whole history tree of a buffer."
  (with-current-html-buffer (output-buffer (format nil "*History-~a*" (id buffer))
                             'nyxt/history-tree-mode:history-tree-mode)
    (with-data-unsafe (history (history-path buffer))
      (let* ((markup:*auto-escape* nil)
             (mode (find-submode output-buffer 'nyxt/history-tree-mode:history-tree-mode))
             (tree `(:ul ,(htree:map-owned-tree
                           #'(lambda (node)
                               `(:li
                                 (:a :href ,(render-url (url (htree:data node)))
                                     ,(let ((title (title-or-fallback (htree:data node))))
                                        (if (eq node (htree:current-owner-node history))
                                            `(:b ,title)
                                            title)))))
                           history
                           :include-root t
                           :collect-function #'(lambda (a b) `(,@a ,(when b `(:ul ,@b))))))))
        (markup:markup
         (:body (:h1 "History")
                (:style (style output-buffer))
                (:style (style mode))
                (:div (markup:raw
                       (markup:markup*
                        tree)))))))))

(define-command history-tree ()         ; TODO: Factor this with `buffer-history-tree'.
  "Open a new buffer displaying the whole history branch the current buffer is on."
  (nyxt::with-current-html-buffer (output-buffer "*History*"
                                                 'nyxt/history-tree-mode:history-tree-mode)
    (with-data-unsafe (history (history-path (current-buffer)))
      (let ((markup:*auto-escape* nil)
            (mode (find-submode output-buffer 'nyxt/history-tree-mode:history-tree-mode))
            (tree `(:ul ,(htree:map-tree
                          #'(lambda (node)
                              `(:li (:a :href ,(render-url (url (htree:data node)))
                                        ,(let ((title (title-or-fallback (htree:data node))))
                                           (cond
                                             ((eq node (htree:current-owner-node history))
                                              `(:i (:b ,title)))
                                             ((htree:owned-p (htree:current-owner history) node)
                                              `(:b ,title))
                                             (t title)))))) ; Color?  Smaller?
                          history
                          :include-root t
                          :collect-function #'(lambda (a b) `(,@a ,(when b `(:ul ,@b))))))))
        (markup:markup
         (:body (:h1 "History")
                (:style (style output-buffer))
                (:style (style mode))
                (:div (markup:raw
                       (markup:markup*
                        tree)))))))))

(define-command list-history (&key (limit 100))
  "Print the user history as a list."
  (with-current-html-buffer (buffer "*History list*" 'nyxt/list-history-mode:list-history-mode)
    (markup:markup
     (:style (style buffer))
     (:style (style (find-submode output-buffer 'nyxt/list-history-mode:list-history-mode)))
     (:h1 "History")
     (:ul (nyxt::history-html-list :limit limit)))))

(define-command paste ()
  "Paste from clipboard into active-element."
  ;; On some systems like Xorg, clipboard pasting happens just-in-time.  So if we
  ;; copy something from the context menu 'Copy' action, upon pasting we will
  ;; retrieve the text from the GTK thread.  This is prone to create
  ;; dead-locks (e.g. when executing a Parenscript that acts upon the clipboard).
  ;;
  ;; To avoid this, we can 'flush' the clipboard to ensure that the copied text
  ;; is present the clipboard and need not be retrieved from the GTK thread.
  ;; TODO: Do we still need to flush now that we have multiple threads?
  ;; (trivial-clipboard:text (trivial-clipboard:text))
  (%paste))

(define-class ring-source (prompter:source)
  ((prompter:name "Clipboard ring")
   (ring :initarg :ring :accessor ring :initform nil)
   (prompter:constructor
    (lambda (source)
      (containers:container->list (ring source))))
   (prompter:actions
    (list (make-command paste* (ring-items)
            (%paste :input-text (first ring-items))))))
  (:export-class-name-p t))
(define-user-class ring-source)

(define-command paste-from-clipboard-ring ()
  "Show `*browser*' clipboard ring and paste selected entry."
  (prompt
   :prompt "Paste from ring"
   :sources (list (make-instance 'user-ring-source
                                 :ring (nyxt::clipboard-ring *browser*)))))

(define-command copy ()
  "Copy selected text to clipboard."
  (let ((input (%copy)))
    (copy-to-clipboard input)
    (echo "Text copied.")))

(define-class autofill-source (prompter:source)
  ((prompter:name "Autofills")
   (prompter:constructor (autofills *browser*))
   (prompter:actions
    (list (make-command autofill* (autofills)
            (let ((selected-fill (first autofills)))
              (cond ((stringp (autofill-fill selected-fill))
                     (%paste :input-text (autofill-fill selected-fill)))
                    ((functionp (autofill-fill selected-fill))
                     (%paste :input-text (funcall (autofill-fill selected-fill))))))))))
  (:export-class-name-p t))
(define-user-class autofill-source)

(define-command autofill ()
  "Fill in a field with a value from a saved list."
  (prompt
   :prompt "Autofill"
   :sources (make-instance 'user-autofill-source)))

(defmethod nyxt:on-signal-notify-uri ((mode web-mode) url)
  (declare (type quri:uri url))
  (unless (or (url-empty-p url)
              (find-if (alex:rcurry #'str:starts-with? (render-url url))
                       (history-blocklist mode)))
    (log:debug "Notify URL ~a for buffer ~a with load status ~a"
               url
               (buffer mode)
               (slot-value (buffer mode) 'nyxt::load-status))
    (when (eq (slot-value (buffer mode) 'nyxt::load-status) :finished)
      ;; We also add history entries here for when URL changes with initiating
      ;; any load, e.g. when clicking on an anchor.
      (with-current-buffer (buffer mode)
        (nyxt::history-add url :title (title (buffer mode))
                               :buffer (buffer mode))
        (with-data-access (history (history-path (buffer mode)))
          (setf (nyxt::scroll-position
                 (htree:data (htree:current (htree:owner history (id (buffer mode))))))
                (nyxt:document-scroll-position (buffer mode)))))))

  url)

(defmethod nyxt:on-signal-notify-title ((mode web-mode) title)
  ;; Title may be updated after the URL, so we need to set the history entry again
  ;; with `on-signal-notify-uri'.
  (on-signal-notify-uri mode (url (buffer mode)))
  title)

(defmethod nyxt:on-signal-load-committed ((mode web-mode) url)
  (declare (ignore mode url))
  nil)

(defmethod nyxt:on-signal-load-finished ((mode web-mode) url)
  (with-current-buffer (buffer mode)
    (nyxt::history-add url :title (title (buffer mode))
                           :buffer (buffer mode)))
  (reset-page-zoom :buffer (buffer mode)
                   :ratio (current-zoom-ratio (buffer mode)))
  (with-data-unsafe (history (history-path (buffer mode)))
    (alex:when-let ((scroll-position
                     (nyxt::scroll-position
                      (htree:data (htree:current (htree:owner history (id (buffer mode))))))))
      (setf (nyxt:document-scroll-position (buffer mode)) scroll-position)))
  url)
