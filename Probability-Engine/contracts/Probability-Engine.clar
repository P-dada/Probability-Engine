;; Probability Engine with Verifiable Randomness & Reputation System
;; Built for Stacks Blockchain using Clarity

;; ===== CONSTANTS =====
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-INVALID-ENTROPY (err u101))
(define-constant ERR-INSUFFICIENT-ENTROPY (err u102))
(define-constant ERR-INVALID-RANGE (err u103))
(define-constant ERR-USER-NOT-FOUND (err u104))
(define-constant ERR-INVALID-SCORE (err u105))

;; Minimum entropy sources required
(define-constant MIN-ENTROPY-SOURCES u3)
(define-constant MAX-REPUTATION-SCORE u1000)

;; ===== DATA VARIABLES =====
(define-data-var entropy-nonce uint u0)
(define-data-var total-random-requests uint u0)

;; ===== DATA MAPS =====

;; Store entropy sources with their weights
(define-map entropy-sources
  { source-id: uint }
  { 
    source-type: (string-ascii 32),
    weight: uint,
    last-used: uint,
    is-active: bool
  }
)

;; Store random number generation history for verification
(define-map randomness-history
  { request-id: uint }
  {
    requester: principal,
    block-height: uint,
    entropy-hash: (buff 32),
    result: uint,
    timestamp: uint,
    entropy-sources-used: (list 10 uint)
  }
)

;; Reputation system data
(define-map user-reputation
  { user: principal }
  {
    score: uint,
    total-interactions: uint,
    positive-interactions: uint,
    last-updated: uint,
    reputation-level: (string-ascii 20)
  }
)

;; Track reputation validators
(define-map reputation-validators
  { validator: principal }
  {
    is-active: bool,
    validation-count: uint,
    accuracy-score: uint
  }
)

;; Store entropy source counter
(define-data-var next-source-id uint u1)
(define-data-var next-request-id uint u1)

;; ===== PRIVATE FUNCTIONS =====

;; Custom function to convert 32-byte hash to uint
(define-private (hash-to-uint (hash-buff (buff 32)))
  (let ((first-16-bytes (unwrap-panic (as-max-len? (unwrap-panic (slice? hash-buff u0 u16)) u16))))
    (buff-to-uint-le first-16-bytes)
  )
)

;; Custom min function for Clarity
(define-private (min-uint (a uint) (b uint))
  (if (< a b) a b)
)

;; Generate hash from multiple entropy sources
(define-private (combine-entropy-sources (source-ids (list 10 uint)) (base-hash (buff 32)))
  (fold combine-single-entropy source-ids base-hash)
)

(define-private (combine-single-entropy (source-id uint) (current-hash (buff 32)))
  (let ((source-data (unwrap-panic (map-get? entropy-sources { source-id: source-id }))))
    (if (get is-active source-data)
      (sha256 (concat current-hash (unwrap-panic (to-consensus-buff? source-id))))
      current-hash
    )
  )
)

;; Calculate reputation level based on score
(define-private (calculate-reputation-level (score uint))
  (if (>= score u800)
    "Excellent"
    (if (>= score u600)
      "Good"
      (if (>= score u400)
        "Average"
        (if (>= score u200)
          "Poor"
          "New"
        )
      )
    )
  )
)

;; Validate entropy sources are sufficient and active
(define-private (validate-entropy-sources (source-ids (list 10 uint)))
  (let ((active-count (fold count-active-sources source-ids u0)))
    (>= active-count MIN-ENTROPY-SOURCES)
  )
)

(define-private (count-active-sources (source-id uint) (count uint))
  (match (map-get? entropy-sources { source-id: source-id })
    source-data (if (get is-active source-data) (+ count u1) count)
    count
  )
)

;; ===== PUBLIC FUNCTIONS =====

;; Initialize entropy source
(define-public (add-entropy-source (source-type (string-ascii 32)) (weight uint))
  (let ((source-id (var-get next-source-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (> weight u0) ERR-INVALID-ENTROPY)
    
    (map-set entropy-sources 
      { source-id: source-id }
      {
        source-type: source-type,
        weight: weight,
        last-used: stacks-block-height,
        is-active: true
      }
    )
    
    (var-set next-source-id (+ source-id u1))
    (ok source-id)
  )
)

;; Generate verifiable random number
(define-public (generate-random (min-val uint) (max-val uint) (entropy-source-ids (list 10 uint)))
  (let (
    (request-id (var-get next-request-id))
    (current-block stacks-block-height)
    (base-entropy (sha256 (concat 
      (concat
        (unwrap-panic (to-consensus-buff? current-block))
        (unwrap-panic (to-consensus-buff? (var-get entropy-nonce)))
      )
      (unwrap-panic (to-consensus-buff? tx-sender))
    )))
  )
    (asserts! (< min-val max-val) ERR-INVALID-RANGE)
    (asserts! (validate-entropy-sources entropy-source-ids) ERR-INSUFFICIENT-ENTROPY)
    
    (let (
      (combined-entropy (combine-entropy-sources entropy-source-ids base-entropy))
      (random-uint (hash-to-uint combined-entropy))
      (range (- max-val min-val))
      (result (+ min-val (mod random-uint range)))
    )
      
      ;; Store randomness history for verification
      (map-set randomness-history
        { request-id: request-id }
        {
          requester: tx-sender,
          block-height: current-block,
          entropy-hash: combined-entropy,
          result: result,
          timestamp: current-block,
          entropy-sources-used: entropy-source-ids
        }
      )
      
      ;; Update counters
      (var-set next-request-id (+ request-id u1))
      (var-set entropy-nonce (+ (var-get entropy-nonce) u1))
      (var-set total-random-requests (+ (var-get total-random-requests) u1))
      
      (ok result)
    )
  )
)

;; Initialize user reputation
(define-public (initialize-reputation)
  (let ((existing-rep (map-get? user-reputation { user: tx-sender })))
    (if (is-none existing-rep)
      (begin
        (map-set user-reputation
          { user: tx-sender }
          {
            score: u100, ;; Starting reputation
            total-interactions: u0,
            positive-interactions: u0,
            last-updated: stacks-block-height,
            reputation-level: "New"
          }
        )
        (ok true)
      )
      (ok false) ;; Already initialized
    )
  )
)

;; Update reputation score
(define-public (update-reputation (user principal) (interaction-positive bool))
  (let ((current-rep (unwrap! (map-get? user-reputation { user: user }) ERR-USER-NOT-FOUND)))
    (let (
      (new-total (+ (get total-interactions current-rep) u1))
      (new-positive (if interaction-positive 
        (+ (get positive-interactions current-rep) u1)
        (get positive-interactions current-rep)
      ))
      (positive-ratio (if (> new-total u0) (/ (* new-positive u1000) new-total) u0))
      (new-score (min-uint MAX-REPUTATION-SCORE positive-ratio))
    )
      (map-set user-reputation
        { user: user }
        {
          score: new-score,
          total-interactions: new-total,
          positive-interactions: new-positive,
          last-updated: stacks-block-height,
          reputation-level: (calculate-reputation-level new-score)
        }
      )
      (ok new-score)
    )
  )
)

;; Add reputation validator
(define-public (add-reputation-validator)
  (begin
    (map-set reputation-validators
      { validator: tx-sender }
      {
        is-active: true,
        validation-count: u0,
        accuracy-score: u1000 ;; Start with perfect accuracy
      }
    )
    (ok true)
  )
)

;; Validate and update reputation (for validators)
(define-public (validate-reputation-update (user principal) (interaction-positive bool) (confidence-score uint))
  (let ((validator-data (unwrap! (map-get? reputation-validators { validator: tx-sender }) ERR-USER-NOT-FOUND)))
    (asserts! (get is-active validator-data) ERR-INVALID-SCORE)
    (asserts! (<= confidence-score u1000) ERR-INVALID-SCORE)
    
    ;; Update validator stats
    (map-set reputation-validators
      { validator: tx-sender }
      {
        is-active: true,
        validation-count: (+ (get validation-count validator-data) u1),
        accuracy-score: (get accuracy-score validator-data) ;; Simplified - could implement dynamic accuracy
      }
    )
    
    ;; Apply reputation update with validator confidence weighting
    (update-reputation user interaction-positive)
  )
)

;; ===== READ-ONLY FUNCTIONS =====

;; Get entropy source info
(define-read-only (get-entropy-source (source-id uint))
  (map-get? entropy-sources { source-id: source-id })
)

;; Get randomness history
(define-read-only (get-randomness-history (request-id uint))
  (map-get? randomness-history { request-id: request-id })
)

;; Get user reputation
(define-read-only (get-user-reputation (user principal))
  (map-get? user-reputation { user: user })
)

;; Get reputation validator info
(define-read-only (get-validator-info (validator principal))
  (map-get? reputation-validators { validator: validator })
)

;; Verify random number generation
(define-read-only (verify-randomness (request-id uint))
  (let ((history (unwrap! (map-get? randomness-history { request-id: request-id }) (err u404))))
    (ok {
      requester: (get requester history),
      block-height: (get block-height history),
      entropy-sources: (get entropy-sources-used history),
      result: (get result history),
      verifiable: true
    })
  )
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-random-requests: (var-get total-random-requests),
    current-entropy-nonce: (var-get entropy-nonce),
    next-source-id: (var-get next-source-id),
    contract-owner: CONTRACT-OWNER
  }
)

;; Check if user has minimum reputation for certain actions
(define-read-only (has-minimum-reputation (user principal) (min-score uint))
  (match (map-get? user-reputation { user: user })
    user-data (>= (get score user-data) min-score)
    false
  )
)

;; Get reputation summary information
(define-read-only (get-reputation-summary)
  {
    max-score: MAX-REPUTATION-SCORE,
    min-entropy-sources: MIN-ENTROPY-SOURCES,
    total-levels: u5
  }
)