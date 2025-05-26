;; Patient Verification Contract
;; Manages participant identities and privacy-preserving patient data

(define-map patients
    { patient-id: uint }
    {
        address: principal,
        encrypted-data-hash: (buff 32),
        consent-given: bool,
        registration-date: uint,
        active: bool
    }
)

(define-map patient-addresses
    { address: principal }
    { patient-id: uint }
)

(define-map patient-consents
    { patient-id: uint, provider-id: uint }
    {
        consent-given: bool,
        consent-date: uint,
        expiry-date: uint
    }
)

(define-data-var next-patient-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-PATIENT-NOT-FOUND (err u201))
(define-constant ERR-PATIENT-ALREADY-EXISTS (err u202))
(define-constant ERR-CONSENT-NOT-GIVEN (err u203))
(define-constant ERR-INVALID-EXPIRY (err u204))

;; Register a new patient
(define-public (register-patient (encrypted-data-hash (buff 32)))
    (let
        (
            (patient-id (var-get next-patient-id))
            (caller tx-sender)
        )
        (asserts! (is-none (map-get? patient-addresses { address: caller })) ERR-PATIENT-ALREADY-EXISTS)

        (map-set patients
            { patient-id: patient-id }
            {
                address: caller,
                encrypted-data-hash: encrypted-data-hash,
                consent-given: true,
                registration-date: block-height,
                active: true
            }
        )

        (map-set patient-addresses
            { address: caller }
            { patient-id: patient-id }
        )

        (var-set next-patient-id (+ patient-id u1))
        (ok patient-id)
    )
)

;; Give consent to a specific provider
(define-public (give-provider-consent (provider-id uint) (expiry-blocks uint))
    (let
        (
            (patient-data (unwrap! (map-get? patient-addresses { address: tx-sender }) ERR-PATIENT-NOT-FOUND))
            (patient-id (get patient-id patient-data))
            (expiry-date (+ block-height expiry-blocks))
        )
        (asserts! (> expiry-blocks u0) ERR-INVALID-EXPIRY)

        (map-set patient-consents
            { patient-id: patient-id, provider-id: provider-id }
            {
                consent-given: true,
                consent-date: block-height,
                expiry-date: expiry-date
            }
        )
        (ok true)
    )
)

;; Revoke consent from a provider
(define-public (revoke-provider-consent (provider-id uint))
    (let
        (
            (patient-data (unwrap! (map-get? patient-addresses { address: tx-sender }) ERR-PATIENT-NOT-FOUND))
            (patient-id (get patient-id patient-data))
        )
        (map-set patient-consents
            { patient-id: patient-id, provider-id: provider-id }
            {
                consent-given: false,
                consent-date: block-height,
                expiry-date: u0
            }
        )
        (ok true)
    )
)

;; Check if patient has given consent to provider
(define-read-only (has-provider-consent (patient-address principal) (provider-id uint))
    (match (map-get? patient-addresses { address: patient-address })
        patient-data
        (let
            (
                (patient-id (get patient-id patient-data))
                (consent-data (map-get? patient-consents { patient-id: patient-id, provider-id: provider-id }))
            )
            (match consent-data
                consent (and
                    (get consent-given consent)
                    (> (get expiry-date consent) block-height)
                )
                false
            )
        )
        false
    )
)

;; Get patient information
(define-read-only (get-patient (patient-id uint))
    (map-get? patients { patient-id: patient-id })
)

;; Get patient by address
(define-read-only (get-patient-by-address (patient-address principal))
    (match (map-get? patient-addresses { address: patient-address })
        patient-data (map-get? patients { patient-id: (get patient-id patient-data) })
        none
    )
)

;; Deactivate patient account
(define-public (deactivate-patient)
    (let
        (
            (patient-data (unwrap! (map-get? patient-addresses { address: tx-sender }) ERR-PATIENT-NOT-FOUND))
            (patient-id (get patient-id patient-data))
            (patient (unwrap! (map-get? patients { patient-id: patient-id }) ERR-PATIENT-NOT-FOUND))
        )
        (map-set patients
            { patient-id: patient-id }
            (merge patient { active: false })
        )
        (ok true)
    )
)
