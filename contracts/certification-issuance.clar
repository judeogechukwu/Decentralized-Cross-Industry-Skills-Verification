;; Certification Issuance Contract
;; Creates and manages authenticated skill credentials

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u400))
(define-constant err-not-authorized (err u401))
(define-constant err-invalid-certification (err u402))
(define-constant err-already-exists (err u403))

;; Data structures
(define-map certifications
  { individual: principal, cert-id: uint }
  {
    skill-id: uint,
    issuer: principal,
    issue-date: uint,
    expiry-date: uint,
    certification-hash: (buff 32),
    status: (string-ascii 20)
  }
)

(define-map certification-templates
  { template-id: uint }
  {
    name: (string-ascii 100),
    required-score: uint,
    validity-period: uint,
    skill-id: uint,
    created-by: principal
  }
)

(define-data-var next-cert-id uint u1)
(define-data-var next-template-id uint u1)

;; Public functions
(define-public (create-certification-template (name (string-ascii 100)) (required-score uint) (validity-period uint) (skill-id uint))
  (let ((template-id (var-get next-template-id)))
    (map-set certification-templates
      { template-id: template-id }
      {
        name: name,
        required-score: required-score,
        validity-period: validity-period,
        skill-id: skill-id,
        created-by: tx-sender
      }
    )
    (var-set next-template-id (+ template-id u1))
    (ok template-id)
  )
)

(define-public (issue-certification (individual principal) (template-id uint) (certification-hash (buff 32)))
  (let ((cert-id (var-get next-cert-id))
        (template (unwrap! (map-get? certification-templates { template-id: template-id }) err-invalid-certification)))
    (map-set certifications
      { individual: individual, cert-id: cert-id }
      {
        skill-id: (get skill-id template),
        issuer: tx-sender,
        issue-date: block-height,
        expiry-date: (+ block-height (get validity-period template)),
        certification-hash: certification-hash,
        status: "active"
      }
    )
    (var-set next-cert-id (+ cert-id u1))
    (ok cert-id)
  )
)

(define-public (revoke-certification (individual principal) (cert-id uint))
  (let ((cert (unwrap! (map-get? certifications { individual: individual, cert-id: cert-id }) err-invalid-certification)))
    (asserts! (is-eq tx-sender (get issuer cert)) err-not-authorized)
    (map-set certifications
      { individual: individual, cert-id: cert-id }
      (merge cert { status: "revoked" })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-certification (individual principal) (cert-id uint))
  (map-get? certifications { individual: individual, cert-id: cert-id })
)

(define-read-only (is-certification-valid (individual principal) (cert-id uint))
  (match (map-get? certifications { individual: individual, cert-id: cert-id })
    cert (and
           (is-eq (get status cert) "active")
           (> (get expiry-date cert) block-height))
    false
  )
)

(define-read-only (get-template (template-id uint))
  (map-get? certification-templates { template-id: template-id })
)
