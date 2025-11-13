;; -----------------------------------------------------------------------------
;; TransPermitChain.clar
;; Transport Permit System on Stacks (Clarity)
;; Version: 1.0
;; Author: Generated for user
;; -----------------------------------------------------------------------------

(define-data-var admin principal tx-sender) ;; contract deployer becomes admin

;; Incremental counters
(define-data-var request-counter uint u0)
(define-data-var permit-counter uint u0)

;; Map: registered authorities who can approve/issue permits
(define-map authorities {authority: principal} {approved: bool})

;; Pending permit requests: request-id -> { requester, vehicle-number, requested-at }
(define-map permit-requests
  { request-id: uint }
  {
    requester: principal,
    vehicle-number: (string-ascii 32),
    requested-at: uint
  }
)

;; Issued permits: permit-id -> permit details
(define-map permits
  { permit-id: uint }
  {
    owner: principal,
    vehicle-number: (string-ascii 32),
    issuer: principal,
    issue-height: uint,
    expiry-height: uint,
    active: bool
  }
)

;; Map to quickly find the latest permit-id by vehicle-number
(define-map vehicle-to-permit
  { vehicle-number: (string-ascii 32) }
  { permit-id: uint })

;; Events (emitted via print statements; Clarity has no dedicated event declaration)
;; Authority registered: print {authority: principal, by: principal}
;; Authority revoked:    print {authority: principal, by: principal}
;; Permit requested:     print {request-id: uint, requester: principal, vehicle-number: (string-ascii 32)}
;; Permit issued:        print {permit-id: uint, owner: principal, vehicle-number: (string-ascii 32), issuer: principal, expiry-height: uint}
;; Permit renewed:       print {permit-id: uint, issuer: principal, new-expiry: uint}
;; Permit revoked:       print {permit-id: uint, issuer: principal}

;; -------------------------
;; Utility / Authorization
;; -------------------------

(define-read-only (is-admin (addr principal))
  (is-eq addr (var-get admin))
)

(define-read-only (is-authority (addr principal))
  (match (map-get? authorities {authority: addr})
    entry
    (get approved entry)
    false))

;; Admin-only: register an authority
(define-public (register-authority (authority principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err "UNAUTHORIZED: only admin"))
  ;; Authority is a principal type by definition, no need to check
  (asserts! (not (is-eq authority 'SP000000000000000000002Q6VF78)) (err "INVALID_AUTHORITY"))
  (map-set authorities {authority: authority} {approved: true})
    (print {event: "authority-registered", authority: authority, by: tx-sender})
    (ok true)
  )
)

;; Admin-only: revoke an authority
(define-public (revoke-authority (authority principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err "UNAUTHORIZED: only admin"))
  ;; Authority is a principal type by definition, no need to check
  (asserts! (not (is-eq authority 'SP000000000000000000002Q6VF78)) (err "INVALID_AUTHORITY"))
  (map-set authorities {authority: authority} {approved: false})
    (print {event: "authority-revoked", authority: authority, by: tx-sender})
    (ok true)
  )
)

;; -------------------------
;; Citizen: Request a permit
;; -------------------------
;; requester calls this (tx-sender) and provides vehicle-number
(define-public (request-permit (vehicle-number (string-ascii 32)))
  (let ((new-id (+ (var-get request-counter) u1)))
    (begin
      ;; Check vehicle-number is not empty (untrusted input)
      (asserts! (> (len vehicle-number) u0) (err "INVALID_VEHICLE_NUMBER"))
      (map-set permit-requests {request-id: new-id}
        {
          requester: tx-sender,
          vehicle-number: vehicle-number,
          requested-at: stacks-block-height
        })
      (var-set request-counter new-id)
      (print {event: "permit-requested", request-id: new-id, requester: tx-sender, vehicle-number: vehicle-number})
      (ok new-id)
    )
  )
)

;; -------------------------
;; Authority: Approve / Issue permit
;; -------------------------
;; Approving authority must be registered (approved)
;; Parameters:
;;   request-id - the pending request to approve
;;   owner      - principal to assign permit to (usually requester)
;;   validity-blocks - number of blocks from now the permit should be valid
(define-public (approve-request (request-id uint) (owner principal) (validity-blocks uint))
  (begin
    ;; check caller is an approved authority
    (asserts! (is-eq (is-authority tx-sender) true) (err "UNAUTHORIZED: not an authority"))
  ;; Owner is a principal type by definition, no need to check
    (asserts! (> validity-blocks u0) (err "INVALID_VALIDITY"))
    ;; fetch pending request
    (match (map-get? permit-requests {request-id: request-id})
      request
      (let (
            (vehicle (get vehicle-number request))
            (new-permit-id (+ (var-get permit-counter) u1))
            (issued-at stacks-block-height)
            (expiry (+ issued-at validity-blocks))
           )
        (begin
          (asserts! (> (len vehicle) u0) (err "INVALID_VEHICLE_NUMBER"))
          ;; create the permit
          (asserts! (not (is-eq owner 'SP000000000000000000002Q6VF78)) (err "INVALID_OWNER"))
          (map-set permits {permit-id: new-permit-id}
            (tuple
              (owner owner)
              (vehicle-number vehicle)
              (issuer tx-sender)
              (issue-height issued-at)
              (expiry-height expiry)
              (active true)
            )
          )
          ;; update vehicle -> permit mapping (latest)
          (map-set vehicle-to-permit {vehicle-number: vehicle} (tuple (permit-id new-permit-id)))
          ;; increment permit counter
          (var-set permit-counter new-permit-id)
          ;; remove pending request (clean up)
          (asserts! (> request-id u0) (err "INVALID_REQUEST_ID"))
          (map-delete permit-requests {request-id: request-id})
          ;; emit event
          (print {event: "permit-issued", permit-id: new-permit-id, owner: owner, vehicle-number: vehicle, issuer: tx-sender, expiry-height: expiry})
          (ok new-permit-id)
        )
      )
      (err "REQUEST_NOT_FOUND")
    )
  )
)

;; -------------------------
;; Authority: Renew permit
;; -------------------------
;; Add extra blocks to existing permit expiry (authority only)
(define-public (renew-permit (permit-id uint) (extra-blocks uint))
  (begin
    (asserts! (is-eq (is-authority tx-sender) true) (err "UNAUTHORIZED: not an authority"))
    (asserts! (> extra-blocks u0) (err "INVALID_BLOCKS"))
    (match (map-get? permits {permit-id: permit-id})
      p
      (let ((current-expiry (get expiry-height p))
            (issuer (get issuer p)))
        (let ((new-expiry (+ current-expiry extra-blocks)))
          (asserts! (> permit-id u0) (err "INVALID_PERMIT_ID"))
          (map-set permits {permit-id: permit-id}
            (tuple
              (owner (get owner p))
              (vehicle-number (get vehicle-number p))
              (issuer issuer)
              (issue-height (get issue-height p))
              (expiry-height new-expiry)
              (active (get active p))
            )
          )
          (print {event: "permit-renewed", permit-id: permit-id, issuer: tx-sender, new-expiry: new-expiry})
          (ok new-expiry)
        )
      )
      (err "PERMIT_NOT_FOUND")
    )
  )
)

;; -------------------------
;; Authority: Revoke permit
;; -------------------------
(define-public (revoke-permit (permit-id uint))
  (begin
    (asserts! (is-eq (is-authority tx-sender) true) (err "UNAUTHORIZED: not an authority"))
    (match (map-get? permits {permit-id: permit-id})
      p
      (begin
  (asserts! (> permit-id u0) (err "INVALID_PERMIT_ID"))
  (map-set permits {permit-id: permit-id}
          (tuple
            (owner (get owner p))
            (vehicle-number (get vehicle-number p))
            (issuer (get issuer p))
            (issue-height (get issue-height p))
            (expiry-height (get expiry-height p))
            (active false)
          )
        )
        (print {event: "permit-revoked", permit-id: permit-id, issuer: tx-sender})
        (ok true)
      )
      (err "PERMIT_NOT_FOUND")
    )
  )
)

;; -------------------------
;; Public Read Functions
;; -------------------------

;; Verify a permit by id - returns tuple { active, expiry-height, owner, vehicle-number, issuer }
(define-read-only (verify-permit (permit-id uint))
  (match (map-get? permits {permit-id: permit-id})
    p
      (let ((is-active (and (get active p) (>= (get expiry-height p) stacks-block-height))))
        (ok
          { status: (if is-active "VALID" "INVALID"),
            expiry: (get expiry-height p),
            owner: (get owner p),
            vehicle-number: (get vehicle-number p),
            issuer: (get issuer p)
          }
        )
      )
    (err "PERMIT_NOT_FOUND")
  )
)

;; Get permit details by ID (raw)
(define-read-only (get-permit (permit-id uint))
  (map-get? permits {permit-id: permit-id})
)

;; Lookup latest permit-id by vehicle number
(define-read-only (get-permit-by-vehicle (vehicle-number (string-ascii 32)))
  (map-get? vehicle-to-permit {vehicle-number: vehicle-number})
)

;; Get pending request details
(define-read-only (get-request (request-id uint))
  (map-get? permit-requests {request-id: request-id})
)

;; Get counts
(define-read-only (get-request-count)
  (ok (var-get request-counter))
)

(define-read-only (get-permit-count)
  (ok (var-get permit-counter))
)

;; -------------------------
;; Helper: Admin can transfer admin role to another principal
;; -------------------------
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err "UNAUTHORIZED: only admin"))
  (asserts! (not (is-eq new-admin 'SP000000000000000000002Q6VF78)) (err "INVALID_ADMIN"))
  (var-set admin new-admin)
    (ok true)
  )
)
