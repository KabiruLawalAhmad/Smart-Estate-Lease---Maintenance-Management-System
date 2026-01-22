(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-lease-active (err u104))
(define-constant err-insufficient-balance (err u105))
(define-constant err-voting-closed (err u106))
(define-constant err-already-voted (err u107))
(define-constant err-transfer-pending (err u108))
(define-constant err-transfer-not-found (err u109))
(define-constant err-transfer-expired (err u110))
(define-constant err-escrow-insufficient (err u111))
(define-constant err-escrow-empty (err u112))
(define-constant err-dispute-not-found (err u113))

(define-non-fungible-token lease-nft uint)
(define-fungible-token estate-token)

(define-data-var next-lease-id uint u1)
(define-data-var next-maintenance-id uint u1)
(define-data-var next-proposal-id uint u1)

(define-map leases
  uint
  {
    property-address: (string-ascii 100),
    landlord: principal,
    tenant: principal,
    monthly-rent: uint,
    deposit-amount: uint,
    lease-start: uint,
    lease-end: uint,
    is-active: bool,
    last-payment: uint,
    late-fee-rate: uint
  }
)

(define-map maintenance-requests
  uint
  {
    lease-id: uint,
    requester: principal,
    description: (string-ascii 500),
    estimated-cost: uint,
    status: (string-ascii 20),
    created-at: uint,
    completed-at: (optional uint)
  }
)

(define-map maintenance-deposits
  uint
  {
    amount: uint,
    staked-by: principal,
    lease-id: uint,
    is-active: bool
  }
)

(define-map proposals
  uint
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    cost: uint,
    proposer: principal,
    votes-for: uint,
    votes-against: uint,
    voting-end: uint,
    is-active: bool,
    executed: bool
  }
)

(define-map user-votes
  { proposal-id: uint, voter: principal }
  bool
)

(define-map expense-logs
  uint
  {
    lease-id: uint,
    amount: uint,
    description: (string-ascii 500),
    category: (string-ascii 50),
    paid-by: principal,
    timestamp: uint
  }
)

(define-data-var next-expense-id uint u1)
(define-data-var next-transfer-id uint u1)

(define-map lease-transfers
  uint
  {
    lease-id: uint,
    current-tenant: principal,
    new-tenant: principal,
    transfer-fee: uint,
    expires-at: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map transfer-history
  { lease-id: uint, transfer-id: uint }
  {
    from-tenant: principal,
    to-tenant: principal,
    transfer-fee: uint,
    completed-at: uint
  }
)

(define-map rent-escrows
  uint
  {
    lease-id: uint,
    tenant: principal,
    amount: uint,
    deposited-at: uint,
    is-active: bool
  }
)

(define-read-only (get-lease (lease-id uint))
  (map-get? leases lease-id)
)

(define-read-only (get-maintenance-request (request-id uint))
  (map-get? maintenance-requests request-id)
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-expense-log (expense-id uint))
  (map-get? expense-logs expense-id)
)

(define-read-only (get-lease-transfer (transfer-id uint))
  (map-get? lease-transfers transfer-id)
)

(define-read-only (get-transfer-history (lease-id uint) (transfer-id uint))
  (map-get? transfer-history { lease-id: lease-id, transfer-id: transfer-id })
)

(define-read-only (get-rent-escrow (escrow-id uint))
  (map-get? rent-escrows escrow-id)
)

(define-read-only (calculate-late-fee (lease-id uint))
  (let ((lease-data (unwrap! (get-lease lease-id) u0)))
    (let ((days-late (/ (- stacks-block-height (get last-payment lease-data)) u144)))
      (if (> days-late u0)
        (* (get monthly-rent lease-data) (get late-fee-rate lease-data) days-late)
        u0
      )
    )
  )
)

(define-public (create-lease 
  (property-address (string-ascii 100))
  (tenant principal)
  (monthly-rent uint)
  (deposit-amount uint)
  (lease-duration uint)
  (late-fee-rate uint)
)
  (let ((lease-id (var-get next-lease-id)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (nft-mint? lease-nft lease-id tenant))
    (map-set leases lease-id {
      property-address: property-address,
      landlord: tx-sender,
      tenant: tenant,
      monthly-rent: monthly-rent,
      deposit-amount: deposit-amount,
      lease-start: stacks-block-height,
      lease-end: (+ stacks-block-height lease-duration),
      is-active: true,
      last-payment: stacks-block-height,
      late-fee-rate: late-fee-rate
    })
    (var-set next-lease-id (+ lease-id u1))
    (try! (ft-mint? estate-token deposit-amount tenant))
    (ok lease-id)
  )
)

(define-public (pay-rent (lease-id uint))
  (let ((lease-data (unwrap! (get-lease lease-id) err-not-found)))
    (asserts! (is-eq tx-sender (get tenant lease-data)) err-unauthorized)
    (asserts! (get is-active lease-data) err-lease-active)
    (let ((late-fee (calculate-late-fee lease-id))
          (total-amount (+ (get monthly-rent lease-data) late-fee)))
      (try! (stx-transfer? total-amount tx-sender (get landlord lease-data)))
      (map-set leases lease-id (merge lease-data { last-payment: stacks-block-height }))
      (unwrap-panic (log-expense lease-id total-amount "Monthly Rent Payment" "rent"))
      (ok total-amount)
    )
  )
)

(define-public (deposit-rent-escrow (lease-id uint) (amount uint))
  (let ((lease-data (unwrap! (get-lease lease-id) err-not-found))
        (escrow-id (var-get next-expense-id)))
    (asserts! (is-eq tx-sender (get tenant lease-data)) err-unauthorized)
    (asserts! (get is-active lease-data) err-lease-active)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set rent-escrows escrow-id {
      lease-id: lease-id,
      tenant: tx-sender,
      amount: amount,
      deposited-at: stacks-block-height,
      is-active: true
    })
    (var-set next-expense-id (+ escrow-id u1))
    (ok escrow-id)
  )
)

(define-public (withdraw-rent-escrow (escrow-id uint))
  (let ((escrow-data (unwrap! (get-rent-escrow escrow-id) err-not-found))
        (lease-data (unwrap! (get-lease (get lease-id escrow-data)) err-not-found)))
    (asserts! (is-eq tx-sender (get tenant escrow-data)) err-unauthorized)
    (asserts! (get is-active escrow-data) err-escrow-empty)
    (asserts! (>= (get amount escrow-data) (get monthly-rent lease-data)) err-escrow-insufficient)
    (try! (as-contract (stx-transfer? (get monthly-rent lease-data) tx-sender (get landlord lease-data))))
    (map-set rent-escrows escrow-id (merge escrow-data {
      amount: (- (get amount escrow-data) (get monthly-rent lease-data)),
      is-active: (> (- (get amount escrow-data) (get monthly-rent lease-data)) u0)
    }))
    (map-set leases (get lease-id escrow-data) (merge lease-data { last-payment: stacks-block-height }))
    (unwrap-panic (log-expense (get lease-id escrow-data) (get monthly-rent lease-data) "Escrow Rent Payment" "rent"))
    (ok (get monthly-rent lease-data))
  )
)

(define-public (submit-maintenance-request 
  (lease-id uint)
  (description (string-ascii 500))
  (estimated-cost uint)
)
  (let ((lease-data (unwrap! (get-lease lease-id) err-not-found))
        (request-id (var-get next-maintenance-id)))
    (asserts! (is-eq tx-sender (get tenant lease-data)) err-unauthorized)
    (map-set maintenance-requests request-id {
      lease-id: lease-id,
      requester: tx-sender,
      description: description,
      estimated-cost: estimated-cost,
      status: "pending",
      created-at: stacks-block-height,
      completed-at: none
    })
    (var-set next-maintenance-id (+ request-id u1))
    (ok request-id)
  )
)

(define-public (stake-maintenance-deposit (lease-id uint) (amount uint))
  (let ((lease-data (unwrap! (get-lease lease-id) err-not-found)))
    (asserts! (>= (ft-get-balance estate-token tx-sender) amount) err-insufficient-balance)
    (try! (ft-burn? estate-token amount tx-sender))
    (map-set maintenance-deposits lease-id {
      amount: amount,
      staked-by: tx-sender,
      lease-id: lease-id,
      is-active: true
    })
    (ok true)
  )
)

(define-public (approve-maintenance (request-id uint))
  (let ((request-data (unwrap! (get-maintenance-request request-id) err-not-found))
        (lease-data (unwrap! (get-lease (get lease-id request-data)) err-not-found)))
    (asserts! (is-eq tx-sender (get landlord lease-data)) err-unauthorized)
    (map-set maintenance-requests request-id (merge request-data { status: "approved" }))
    (ok true)
  )
)

(define-public (complete-maintenance (request-id uint) (actual-cost uint))
  (let ((request-data (unwrap! (get-maintenance-request request-id) err-not-found))
        (lease-data (unwrap! (get-lease (get lease-id request-data)) err-not-found)))
    (asserts! (is-eq tx-sender (get landlord lease-data)) err-unauthorized)
    (map-set maintenance-requests request-id (merge request-data { 
      status: "completed",
      completed-at: (some stacks-block-height)
    }))
    (unwrap-panic (log-expense (get lease-id request-data) actual-cost (get description request-data) "maintenance"))
    (ok true)
  )
)

(define-public (create-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (cost uint)
  (voting-duration uint)
)
  (let ((proposal-id (var-get next-proposal-id)))
    (map-set proposals proposal-id {
      title: title,
      description: description,
      cost: cost,
      proposer: tx-sender,
      votes-for: u0,
      votes-against: u0,
      voting-end: (+ stacks-block-height voting-duration),
      is-active: true,
      executed: false
    })
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let ((proposal-data (unwrap! (get-proposal proposal-id) err-not-found)))
    (asserts! (get is-active proposal-data) err-voting-closed)
    (asserts! (<= stacks-block-height (get voting-end proposal-data)) err-voting-closed)
    (asserts! (is-none (map-get? user-votes { proposal-id: proposal-id, voter: tx-sender })) err-already-voted)
    (map-set user-votes { proposal-id: proposal-id, voter: tx-sender } vote)
    (if vote
      (map-set proposals proposal-id (merge proposal-data { votes-for: (+ (get votes-for proposal-data) u1) }))
      (map-set proposals proposal-id (merge proposal-data { votes-against: (+ (get votes-against proposal-data) u1) }))
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let ((proposal-data (unwrap! (get-proposal proposal-id) err-not-found)))
    (asserts! (> stacks-block-height (get voting-end proposal-data)) err-voting-closed)
    (asserts! (not (get executed proposal-data)) err-unauthorized)
    (asserts! (> (get votes-for proposal-data) (get votes-against proposal-data)) err-unauthorized)
    (map-set proposals proposal-id (merge proposal-data { executed: true, is-active: false }))
    (unwrap-panic (log-expense u0 (get cost proposal-data) (get title proposal-data) "upgrade"))
    (ok true)
  )
)

(define-private (log-expense (lease-id uint) (amount uint) (description (string-ascii 500)) (category (string-ascii 50)))
  (let ((expense-id (var-get next-expense-id)))
    (map-set expense-logs expense-id {
      lease-id: lease-id,
      amount: amount,
      description: description,
      category: category,
      paid-by: tx-sender,
      timestamp: stacks-block-height
    })
    (var-set next-expense-id (+ expense-id u1))
    (ok expense-id)
  )
)

(define-public (terminate-lease (lease-id uint))
  (let ((lease-data (unwrap! (get-lease lease-id) err-not-found)))
    (asserts! (is-eq tx-sender (get landlord lease-data)) err-unauthorized)
    (map-set leases lease-id (merge lease-data { is-active: false }))
    (let ((deposit-data (map-get? maintenance-deposits lease-id)))
      (match deposit-data
        deposit-info (try! (ft-mint? estate-token (get amount deposit-info) (get staked-by deposit-info)))
        true
      )
    )
    (ok true)
  )
)

(define-public (initiate-lease-transfer 
  (lease-id uint)
  (new-tenant principal)
  (transfer-fee uint)
  (expiry-duration uint)
)
  (let ((lease-data (unwrap! (get-lease lease-id) err-not-found))
        (transfer-id (var-get next-transfer-id)))
    (asserts! (is-eq tx-sender (get tenant lease-data)) err-unauthorized)
    (asserts! (get is-active lease-data) err-lease-active)
    (map-set lease-transfers transfer-id {
      lease-id: lease-id,
      current-tenant: tx-sender,
      new-tenant: new-tenant,
      transfer-fee: transfer-fee,
      expires-at: (+ stacks-block-height expiry-duration),
      status: "pending",
      created-at: stacks-block-height
    })
    (var-set next-transfer-id (+ transfer-id u1))
    (ok transfer-id)
  )
)

(define-public (approve-lease-transfer (transfer-id uint))
  (let ((transfer-data (unwrap! (get-lease-transfer transfer-id) err-transfer-not-found))
        (lease-data (unwrap! (get-lease (get lease-id transfer-data)) err-not-found)))
    (asserts! (is-eq tx-sender (get landlord lease-data)) err-unauthorized)
    (asserts! (is-eq (get status transfer-data) "pending") err-unauthorized)
    (asserts! (<= stacks-block-height (get expires-at transfer-data)) err-transfer-expired)
    (map-set lease-transfers transfer-id (merge transfer-data { status: "approved" }))
    (ok true)
  )
)

(define-public (execute-lease-transfer (transfer-id uint))
  (let ((transfer-data (unwrap! (get-lease-transfer transfer-id) err-transfer-not-found))
        (lease-data (unwrap! (get-lease (get lease-id transfer-data)) err-not-found)))
    (asserts! (is-eq tx-sender (get new-tenant transfer-data)) err-unauthorized)
    (asserts! (is-eq (get status transfer-data) "approved") err-unauthorized)
    (asserts! (<= stacks-block-height (get expires-at transfer-data)) err-transfer-expired)
    (try! (stx-transfer? (get transfer-fee transfer-data) tx-sender (get current-tenant transfer-data)))
    (try! (nft-transfer? lease-nft (get lease-id transfer-data) (get current-tenant transfer-data) tx-sender))
    (map-set leases (get lease-id transfer-data) (merge lease-data { tenant: tx-sender }))
    (map-set lease-transfers transfer-id (merge transfer-data { status: "completed" }))
    (map-set transfer-history { lease-id: (get lease-id transfer-data), transfer-id: transfer-id } {
      from-tenant: (get current-tenant transfer-data),
      to-tenant: tx-sender,
      transfer-fee: (get transfer-fee transfer-data),
      completed-at: stacks-block-height
    })
    (unwrap-panic (log-expense (get lease-id transfer-data) (get transfer-fee transfer-data) "Lease Transfer Fee" "transfer"))
    (ok true)
  )
)

(define-public (cancel-lease-transfer (transfer-id uint))
  (let ((transfer-data (unwrap! (get-lease-transfer transfer-id) err-transfer-not-found)))
    (asserts! (is-eq tx-sender (get current-tenant transfer-data)) err-unauthorized)
    (asserts! (is-eq (get status transfer-data) "pending") err-unauthorized)
    (map-set lease-transfers transfer-id (merge transfer-data { status: "cancelled" }))
    (ok true)
  )
)

(define-data-var next-extension-id uint u1)
(define-data-var next-dispute-id uint u1)
(define-data-var next-rating-id uint u1)

(define-map extension-requests
  uint
  {
    lease-id: uint,
    requested-duration: uint,
    status: (string-ascii 20),
    requested-by: principal,
    approved-by: (optional principal)
  }
)

(define-map lease-disputes
  uint
  {
    lease-id: uint,
    raised-by: principal,
    description: (string-ascii 500),
    status: (string-ascii 20),
    raised-at: uint,
    resolved-at: (optional uint),
    resolution: (optional (string-ascii 500))
  }
)

(define-map lease-ratings
  uint
  {
    lease-id: uint,
    rated-by: principal,
    rated-user: principal,
    rating: uint,
    comment: (string-ascii 200),
    submitted-at: uint
  }
)

(define-read-only (get-extension-request (request-id uint))
  (map-get? extension-requests request-id)
)

(define-read-only (get-lease-dispute (dispute-id uint))
  (map-get? lease-disputes dispute-id)
)

(define-read-only (get-lease-rating (rating-id uint))
  (map-get? lease-ratings rating-id)
)

(define-public (request-lease-extension (lease-id uint) (additional-duration uint))
  (let ((lease-data (unwrap! (get-lease lease-id) err-not-found))
        (request-id (var-get next-extension-id)))
    (asserts! (is-eq tx-sender (get tenant lease-data)) err-unauthorized)
    (asserts! (get is-active lease-data) err-lease-active)
    (map-set extension-requests request-id {
      lease-id: lease-id,
      requested-duration: additional-duration,
      status: "pending",
      requested-by: tx-sender,
      approved-by: none
    })
    (var-set next-extension-id (+ request-id u1))
    (ok request-id)
  )
)

(define-public (approve-lease-extension (request-id uint))
  (let ((request-data (unwrap! (get-extension-request request-id) err-not-found))
        (lease-data (unwrap! (get-lease (get lease-id request-data)) err-not-found)))
    (asserts! (is-eq tx-sender (get landlord lease-data)) err-unauthorized)
    (asserts! (is-eq (get status request-data) "pending") err-unauthorized)
    (map-set extension-requests request-id (merge request-data { status: "approved", approved-by: (some tx-sender) }))
    (map-set leases (get lease-id request-data) (merge lease-data { lease-end: (+ (get lease-end lease-data) (get requested-duration request-data)) }))
    (ok true)
  )
)

(define-public (raise-lease-dispute (lease-id uint) (description (string-ascii 500)))
  (let ((lease-data (unwrap! (get-lease lease-id) err-not-found))
        (dispute-id (var-get next-dispute-id)))
    (asserts! (or (is-eq tx-sender (get tenant lease-data)) (is-eq tx-sender (get landlord lease-data))) err-unauthorized)
    (asserts! (get is-active lease-data) err-lease-active)
    (map-set lease-disputes dispute-id {
      lease-id: lease-id,
      raised-by: tx-sender,
      description: description,
      status: "open",
      raised-at: stacks-block-height,
      resolved-at: none,
      resolution: none
    })
    (var-set next-dispute-id (+ dispute-id u1))
    (ok dispute-id)
  )
)

(define-public (resolve-lease-dispute (dispute-id uint) (resolution (string-ascii 500)))
  (let ((dispute-data (unwrap! (get-lease-dispute dispute-id) err-dispute-not-found))
        (lease-data (unwrap! (get-lease (get lease-id dispute-data)) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (get status dispute-data) "open") err-unauthorized)
    (map-set lease-disputes dispute-id (merge dispute-data {
      status: "resolved",
      resolved-at: (some stacks-block-height),
      resolution: (some resolution)
    }))
    (ok true)
  )
)

(define-public (submit-lease-rating (lease-id uint) (rated-user principal) (rating uint) (comment (string-ascii 200)))
  (let ((lease-data (unwrap! (get-lease lease-id) err-not-found))
        (rating-id (var-get next-rating-id)))
    (asserts! (not (get is-active lease-data)) err-lease-active)
    (asserts! (or (is-eq tx-sender (get tenant lease-data)) (is-eq tx-sender (get landlord lease-data))) err-unauthorized)
    (asserts! (is-eq rated-user (if (is-eq tx-sender (get tenant lease-data)) (get landlord lease-data) (get tenant lease-data))) err-unauthorized)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-amount)
    (map-set lease-ratings rating-id {
      lease-id: lease-id,
      rated-by: tx-sender,
      rated-user: rated-user,
      rating: rating,
      comment: comment,
      submitted-at: stacks-block-height
    })
    (var-set next-rating-id (+ rating-id u1))
    (ok rating-id)
  )
)
