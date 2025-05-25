;; Employer Verification Contract
;; Enables employers to verify worker skills and certifications

(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u500))
(define-constant err-unauthorized (err u501))
(define-constant err-already-registered (err u502))

;; Data structures
(define-map registered-employers
  { employer: principal }
  {
    company-name: (string-ascii 100),
    industry: (string-ascii 50),
    registration-date: uint,
    verification-count: uint
  }
)

(define-map verification-requests
  { employer: principal, request-id: uint }
  {
    individual: principal,
    skill-ids: (list 10 uint),
    request-date: uint,
    status: (string-ascii 20),
    response-hash: (optional (buff 32))
  }
)

(define-data-var next-request-id uint u1)

;; Public functions
(define-public (register-employer (company-name (string-ascii 100)) (industry (string-ascii 50)))
  (let ((employer tx-sender))
    (asserts! (is-none (map-get? registered-employers { employer: employer })) err-already-registered)
    (map-set registered-employers
      { employer: employer }
      {
        company-name: company-name,
        industry: industry,
        registration-date: block-height,
        verification-count: u0
      }
    )
    (ok true)
  )
)

(define-public (request-skill-verification (individual principal) (skill-ids (list 10 uint)))
  (let ((request-id (var-get next-request-id))
        (employer tx-sender))
    (asserts! (is-some (map-get? registered-employers { employer: employer })) err-not-found)
    (map-set verification-requests
      { employer: employer, request-id: request-id }
      {
        individual: individual,
        skill-ids: skill-ids,
        request-date: block-height,
        status: "pending",
        response-hash: none
      }
    )
    (var-set next-request-id (+ request-id u1))
    (ok request-id)
  )
)

(define-public (respond-to-verification (employer principal) (request-id uint) (response-hash (buff 32)))
  (let ((request (unwrap! (map-get? verification-requests { employer: employer, request-id: request-id }) err-not-found)))
    (asserts! (is-eq tx-sender (get individual request)) err-unauthorized)
    (map-set verification-requests
      { employer: employer, request-id: request-id }
      (merge request { status: "completed", response-hash: (some response-hash) })
    )
    ;; Update employer verification count
    (map-set registered-employers
      { employer: employer }
      (merge (unwrap-panic (map-get? registered-employers { employer: employer }))
             { verification-count: (+ (get verification-count (unwrap-panic (map-get? registered-employers { employer: employer }))) u1) })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-employer-info (employer principal))
  (map-get? registered-employers { employer: employer })
)

(define-read-only (get-verification-request (employer principal) (request-id uint))
  (map-get? verification-requests { employer: employer, request-id: request-id })
)

(define-read-only (is-employer-registered (employer principal))
  (is-some (map-get? registered-employers { employer: employer }))
)
