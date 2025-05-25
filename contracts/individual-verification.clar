;; Individual Verification Contract
;; Manages worker identity verification and registration

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-verified (err u101))
(define-constant err-not-found (err u102))
(define-constant err-unauthorized (err u103))

;; Data structures
(define-map verified-individuals
  { individual: principal }
  {
    verified: bool,
    verification-date: uint,
    verifier: principal,
    identity-hash: (buff 32)
  }
)

(define-map individual-profiles
  { individual: principal }
  {
    name: (string-ascii 100),
    email-hash: (buff 32),
    created-at: uint,
    status: (string-ascii 20)
  }
)

;; Public functions
(define-public (register-individual (name (string-ascii 100)) (email-hash (buff 32)))
  (let ((individual tx-sender))
    (asserts! (is-none (map-get? individual-profiles { individual: individual })) err-already-verified)
    (map-set individual-profiles
      { individual: individual }
      {
        name: name,
        email-hash: email-hash,
        created-at: block-height,
        status: "pending"
      }
    )
    (ok true)
  )
)

(define-public (verify-individual (individual principal) (identity-hash (buff 32)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (map-get? individual-profiles { individual: individual })) err-not-found)
    (map-set verified-individuals
      { individual: individual }
      {
        verified: true,
        verification-date: block-height,
        verifier: tx-sender,
        identity-hash: identity-hash
      }
    )
    (map-set individual-profiles
      { individual: individual }
      (merge (unwrap-panic (map-get? individual-profiles { individual: individual }))
             { status: "verified" })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (is-verified (individual principal))
  (default-to false (get verified (map-get? verified-individuals { individual: individual })))
)

(define-read-only (get-individual-profile (individual principal))
  (map-get? individual-profiles { individual: individual })
)

(define-read-only (get-verification-details (individual principal))
  (map-get? verified-individuals { individual: individual })
)
