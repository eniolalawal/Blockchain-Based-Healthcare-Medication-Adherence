;; Provider Verification Contract
;; Validates healthcare entities and manages their credentials

(define-map providers
    { provider-id: uint }
    {
        address: principal,
        name: (string-ascii 100),
        license-number: (string-ascii 50),
        specialty: (string-ascii 50),
        verified: bool,
        verification-date: uint
    }
)

(define-map provider-addresses
    { address: principal }
    { provider-id: uint }
)

(define-data-var next-provider-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROVIDER-NOT-FOUND (err u101))
(define-constant ERR-PROVIDER-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-PROVIDER (err u103))

;; Register a new healthcare provider
(define-public (register-provider (name (string-ascii 100)) (license-number (string-ascii 50)) (specialty (string-ascii 50)))
    (let
        (
            (provider-id (var-get next-provider-id))
            (caller tx-sender)
        )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? provider-addresses { address: caller })) ERR-PROVIDER-ALREADY-EXISTS)

        (map-set providers
            { provider-id: provider-id }
            {
                address: caller,
                name: name,
                license-number: license-number,
                specialty: specialty,
                verified: false,
                verification-date: u0
            }
        )

        (map-set provider-addresses
            { address: caller }
            { provider-id: provider-id }
        )

        (var-set next-provider-id (+ provider-id u1))
        (ok provider-id)
    )
)

;; Verify a healthcare provider
(define-public (verify-provider (provider-id uint))
    (let
        (
            (provider (unwrap! (map-get? providers { provider-id: provider-id }) ERR-PROVIDER-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)

        (map-set providers
            { provider-id: provider-id }
            (merge provider { verified: true, verification-date: block-height })
        )
        (ok true)
    )
)

;; Check if provider is verified
(define-read-only (is-provider-verified (provider-address principal))
    (match (map-get? provider-addresses { address: provider-address })
        provider-data
        (match (map-get? providers { provider-id: (get provider-id provider-data) })
            provider (get verified provider)
            false
        )
        false
    )
)

;; Get provider information
(define-read-only (get-provider (provider-id uint))
    (map-get? providers { provider-id: provider-id })
)

;; Get provider by address
(define-read-only (get-provider-by-address (provider-address principal))
    (match (map-get? provider-addresses { address: provider-address })
        provider-data (map-get? providers { provider-id: (get provider-id provider-data) })
        none
    )
)
