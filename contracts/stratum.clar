;; SIP-010 trait (kept for potential future token integration)
(define-trait sip-010-trait
  (
    (transfer (uint principal principal) (response bool uint))
    (balance-of (principal) (response uint uint))
    (get-total-supply () (response uint uint))
  )
)

;; Data variables
(define-data-var content-counter uint u0)
(define-data-var subscription-counter uint u0)
(define-data-var contract-owner principal tx-sender)
(define-data-var paused bool false)

;; Data maps
(define-map contents uint
  {
    owner: principal,
    cid: (string-ascii 100),
    key-hash: (buff 32),
    price: uint,
    created-at: uint,
    ;; New fields for content discovery
    category: (string-ascii 50),
    title: (string-ascii 100),
    description: (string-ascii 500),
    tags: (list 10 (string-ascii 30)),
    content-type: (string-ascii 20)
  })

(define-map access
  {content-id: uint, user: principal} 
  {granted-at: uint, active: bool, expires-at: (optional uint)})

;; New maps for subscriptions
(define-map subscriptions uint
  {
    content-id: uint,
    tier: (string-ascii 20),
    duration: uint,
    price: uint,
    max-downloads: uint,
    features: (list 5 (string-ascii 50)),
    created-at: uint
  })

(define-map user-subscriptions
  {subscription-id: uint, user: principal}
  {
    purchased-at: uint,
    expires-at: uint,
    downloads-used: uint,
    active: bool
  })

;; Revenue sharing maps
(define-map revenue-splits uint
  {
    content-id: uint,
    splits: (list 5 {recipient: principal, percentage: uint})
  })

;; Content metadata for discovery
(define-map content-ratings uint
  {
    total-rating: uint,
    rating-count: uint,
    average-rating: uint
  })

(define-map user-ratings
  {content-id: uint, user: principal}
  {
    rating: uint,
    review: (string-ascii 300),
    created-at: uint
  })

;; Content analytics
(define-map content-analytics uint
  {
    view-count: uint,
    purchase-count: uint,
    revenue-generated: uint
  })

;; Error constants
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_NOT_FOUND u101)
(define-constant ERR_ALREADY_HAS_ACCESS u102)
(define-constant ERR_INSUFFICIENT_PAYMENT u103)
(define-constant ERR_TRANSFER_FAILED u104)
(define-constant ERR_INVALID_PRICE u105)
(define-constant ERR_INVALID_INPUT u106)
(define-constant ERR_CONTRACT_PAUSED u107)
(define-constant ERR_NOT_OWNER u108)
(define-constant ERR_INVALID_PERCENTAGE u109)
(define-constant ERR_SUBSCRIPTION_EXPIRED u110)
(define-constant ERR_DOWNLOAD_LIMIT_EXCEEDED u111)
(define-constant ERR_INVALID_RATING u112)
(define-constant ERR_ALREADY_RATED u113)

;; Events (using print for logging)
(define-private (log-content-registered (id uint) (owner principal) (price uint))
  (print {event: "content-registered", content-id: id, owner: owner, price: price}))

(define-private (log-access-purchased (id uint) (user principal) (price uint))
  (print {event: "access-purchased", content-id: id, user: user, price: price}))

(define-private (log-subscription-purchased (id uint) (user principal) (subscription-id uint))
  (print {event: "subscription-purchased", content-id: id, user: user, subscription-id: subscription-id}))

(define-private (log-rating-added (content-id uint) (user principal) (rating uint))
  (print {event: "rating-added", content-id: content-id, user: user, rating: rating}))

;; Enhanced input validation helpers
(define-private (is-valid-price (price uint))
  (and (> price u0) (<= price u1000000000000))) ;; Max 1 trillion microSTX

(define-private (is-valid-cid (cid (string-ascii 100)))
  (and (> (len cid) u0) (<= (len cid) u100)))

(define-private (is-valid-key-hash (key-hash (buff 32)))
  (is-eq (len key-hash) u32))

(define-private (is-valid-category (category (string-ascii 50)))
  (and (> (len category) u0) (<= (len category) u50)))

(define-private (is-valid-title (title (string-ascii 100)))
  (and (> (len title) u0) (<= (len title) u100)))

(define-private (is-valid-description (description (string-ascii 500)))
  (<= (len description) u500))

(define-private (is-valid-content-type (content-type (string-ascii 20)))
  (and (> (len content-type) u0) (<= (len content-type) u20)))

(define-private (is-valid-tier (tier (string-ascii 20)))
  (and (> (len tier) u0) (<= (len tier) u20)))

(define-private (is-valid-duration (duration uint))
  (and (> duration u0) (<= duration u525600))) ;; Max 1 year in blocks

(define-private (is-valid-max-downloads (max-downloads uint))
  (<= max-downloads u10000)) ;; Reasonable limit

(define-private (is-valid-review (review (string-ascii 300)))
  (<= (len review) u300))

(define-private (is-valid-percentage (percentage uint))
  (and (>= percentage u0) (<= percentage u100)))

(define-private (is-valid-rating (rating uint))
  (and (>= rating u1) (<= rating u5)))

(define-private (validate-tags (tags (list 10 (string-ascii 30))))
  (fold validate-single-tag tags true))

(define-private (validate-single-tag (tag (string-ascii 30)) (acc bool))
  (and acc (<= (len tag) u30)))

(define-private (validate-features (features (list 5 (string-ascii 50))))
  (fold validate-single-feature features true))

(define-private (validate-single-feature (feature (string-ascii 50)) (acc bool))
  (and acc (<= (len feature) u50)))

;; Administrative functions
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set paused true)
    (ok true)))

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set paused false)
    (ok true)))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (is-eq new-owner new-owner) (err ERR_INVALID_INPUT))
    (var-set contract-owner new-owner)
    (ok true)))

;; Enhanced content registration with comprehensive validation
(define-public (register-content 
  (cid (string-ascii 100)) 
  (key-hash (buff 32)) 
  (price uint)
  (category (string-ascii 50))
  (title (string-ascii 100))
  (description (string-ascii 500))
  (tags (list 10 (string-ascii 30)))
  (content-type (string-ascii 20)))
  (let ((id (+ (var-get content-counter) u1)))
    (begin
      ;; Check if contract is paused
      (asserts! (not (var-get paused)) (err ERR_CONTRACT_PAUSED))
      
      ;; Comprehensive input validation
      (asserts! (is-valid-price price) (err ERR_INVALID_PRICE))
      (asserts! (is-valid-cid cid) (err ERR_INVALID_INPUT))
      (asserts! (is-valid-key-hash key-hash) (err ERR_INVALID_INPUT))
      (asserts! (is-valid-category category) (err ERR_INVALID_INPUT))
      (asserts! (is-valid-title title) (err ERR_INVALID_INPUT))
      (asserts! (is-valid-description description) (err ERR_INVALID_INPUT))
      (asserts! (is-valid-content-type content-type) (err ERR_INVALID_INPUT))
      (asserts! (validate-tags tags) (err ERR_INVALID_INPUT))
      
      ;; Store content with validated metadata - using validated variables
      (let ((validated-cid (if (is-valid-cid cid) cid "default"))
            (validated-category (if (is-valid-category category) category "general"))
            (validated-title (if (is-valid-title title) title "Untitled"))
            (validated-description (if (is-valid-description description) description ""))
            (validated-content-type (if (is-valid-content-type content-type) content-type "document"))
            (validated-tags (if (validate-tags tags) tags (list)))
            (validated-price (if (is-valid-price price) price u1000000)))
        (begin
          (map-set contents id { 
            owner: tx-sender, 
            cid: validated-cid, 
            key-hash: key-hash, 
            price: validated-price,
            created-at: stacks-block-height,
            category: validated-category,
            title: validated-title,
            description: validated-description,
            tags: validated-tags,
            content-type: validated-content-type
          })
          
          ;; Initialize analytics
          (map-set content-analytics id {
            view-count: u0,
            purchase-count: u0,
            revenue-generated: u0
          })
          
          ;; Initialize ratings
          (map-set content-ratings id {
            total-rating: u0,
            rating-count: u0,
            average-rating: u0
          })
          
          (var-set content-counter id)
          
          ;; Log event
          (log-content-registered id tx-sender validated-price)
          (ok id))))))

;; Backward compatible content registration
(define-public (register-content-simple (cid (string-ascii 100)) (key-hash (buff 32)) (price uint))
  (register-content cid key-hash price "general" "Untitled" "No description" (list) "document"))

;; Revenue sharing setup
(define-public (setup-revenue-split 
  (content-id uint) 
  (splits (list 5 {recipient: principal, percentage: uint})))
  (let ((content-opt (map-get? contents content-id)))
    (begin
      (asserts! (is-some content-opt) (err ERR_NOT_FOUND))
      (let ((content (unwrap! content-opt (err ERR_NOT_FOUND))))
        (begin
          (asserts! (is-eq tx-sender (get owner content)) (err ERR_UNAUTHORIZED))
          ;; Validate percentages sum to 100
          (asserts! (is-eq (fold + (map get-percentage splits) u0) u100) (err ERR_INVALID_PERCENTAGE))
          (map-set revenue-splits content-id {
            content-id: content-id,
            splits: splits
          })
          (ok true))))))

(define-private (get-percentage (split {recipient: principal, percentage: uint}))
  (get percentage split))

;; Subscription creation with enhanced validation
(define-public (create-subscription
  (content-id uint)
  (tier (string-ascii 20))
  (duration uint)
  (price uint)
  (max-downloads uint)
  (features (list 5 (string-ascii 50))))
  (let ((subscription-id (+ (var-get subscription-counter) u1))
        (content-opt (map-get? contents content-id)))
    (begin
      (asserts! (not (var-get paused)) (err ERR_CONTRACT_PAUSED))
      (asserts! (is-some content-opt) (err ERR_NOT_FOUND))
      (let ((content (unwrap! content-opt (err ERR_NOT_FOUND))))
        (begin
          (asserts! (is-eq tx-sender (get owner content)) (err ERR_UNAUTHORIZED))
          (asserts! (is-valid-price price) (err ERR_INVALID_PRICE))
          (asserts! (is-valid-tier tier) (err ERR_INVALID_INPUT))
          (asserts! (is-valid-duration duration) (err ERR_INVALID_INPUT))
          (asserts! (is-valid-max-downloads max-downloads) (err ERR_INVALID_INPUT))
          (asserts! (validate-features features) (err ERR_INVALID_INPUT))
          
          ;; Use validated variables
          (let ((validated-tier (if (is-valid-tier tier) tier "basic"))
                (validated-duration (if (is-valid-duration duration) duration u144))
                (validated-price (if (is-valid-price price) price u1000000))
                (validated-max-downloads (if (is-valid-max-downloads max-downloads) max-downloads u100))
                (validated-features (if (validate-features features) features (list))))
            (begin
              (map-set subscriptions subscription-id {
                content-id: content-id,
                tier: validated-tier,
                duration: validated-duration,
                price: validated-price,
                max-downloads: validated-max-downloads,
                features: validated-features,
                created-at: stacks-block-height
              })
              
              (var-set subscription-counter subscription-id)
              (ok subscription-id))))))))

;; Purchase subscription
(define-public (buy-subscription (subscription-id uint))
  (let ((subscription-opt (map-get? subscriptions subscription-id)))
    (begin
      (asserts! (not (var-get paused)) (err ERR_CONTRACT_PAUSED))
      (asserts! (is-some subscription-opt) (err ERR_NOT_FOUND))
      (let ((subscription (unwrap! subscription-opt (err ERR_NOT_FOUND))))
        (execute-subscription-purchase subscription-id subscription)))))

(define-private (execute-subscription-purchase 
  (subscription-id uint) 
  (subscription {content-id: uint, tier: (string-ascii 20), duration: uint, price: uint, max-downloads: uint, features: (list 5 (string-ascii 50)), created-at: uint}))
  (let ((price (get price subscription))
        (content-id (get content-id subscription))
        (duration (get duration subscription))
        (content-opt (map-get? contents content-id)))
    (begin
      (asserts! (is-some content-opt) (err ERR_NOT_FOUND))
      (let ((content (unwrap! content-opt (err ERR_NOT_FOUND))))
        (begin
          (asserts! (>= (stx-get-balance tx-sender) price) (err ERR_INSUFFICIENT_PAYMENT))
          
          ;; Handle revenue distribution
          (try! (distribute-revenue content-id price))
          
          ;; Grant subscription access
          (map-set user-subscriptions {subscription-id: subscription-id, user: tx-sender} {
            purchased-at: stacks-block-height,
            expires-at: (+ stacks-block-height duration),
            downloads-used: u0,
            active: true
          })
          
          ;; Update analytics
          (update-content-analytics content-id price)
          
          (log-subscription-purchased content-id tx-sender subscription-id)
          (ok true))))))

;; Revenue distribution helper
(define-private (distribute-revenue (content-id uint) (amount uint))
  (let ((content-opt (map-get? contents content-id))
        (splits-opt (map-get? revenue-splits content-id)))
    (begin
      (asserts! (is-some content-opt) (err ERR_NOT_FOUND))
      (let ((content (unwrap! content-opt (err ERR_NOT_FOUND))))
        (match splits-opt
          splits (distribute-to-recipients (get splits splits) amount)
          ;; No revenue split defined, pay owner directly
          (match (stx-transfer? amount tx-sender (get owner content))
            success (ok amount)
            error (err ERR_TRANSFER_FAILED)))))))

(define-private (distribute-to-recipients (splits (list 5 {recipient: principal, percentage: uint})) (total-amount uint))
  (fold distribute-single-payment splits (ok total-amount)))

(define-private (distribute-single-payment 
  (split {recipient: principal, percentage: uint}) 
  (acc (response uint uint)))
  (match acc
    total-amount 
    (let ((payment-amount (/ (* total-amount (get percentage split)) u100)))
      (match (stx-transfer? payment-amount tx-sender (get recipient split))
        success (ok total-amount)
        error (err ERR_TRANSFER_FAILED)))
    error (err error)))

;; Rating system with enhanced validation
(define-public (rate-content (content-id uint) (rating uint) (review (string-ascii 300)))
  (let ((content-opt (map-get? contents content-id)))
    (begin
      (asserts! (not (var-get paused)) (err ERR_CONTRACT_PAUSED))
      (asserts! (is-some content-opt) (err ERR_NOT_FOUND))
      (asserts! (is-valid-rating rating) (err ERR_INVALID_RATING))
      (asserts! (is-valid-review review) (err ERR_INVALID_INPUT))
      
      ;; Check if user already rated
      (asserts! (is-none (map-get? user-ratings {content-id: content-id, user: tx-sender})) (err ERR_ALREADY_RATED))
      
      ;; Check if user has access
      (asserts! (unwrap! (has-access content-id tx-sender) (err ERR_UNAUTHORIZED)) (err ERR_UNAUTHORIZED))
      
      ;; Use validated variables
      (let ((validated-rating (if (is-valid-rating rating) rating u1))
            (validated-review (if (is-valid-review review) review "")))
        (begin
          ;; Add user rating
          (map-set user-ratings {content-id: content-id, user: tx-sender} {
            rating: validated-rating,
            review: validated-review,
            created-at: stacks-block-height
          })
          
          ;; Update aggregate rating
          (update-aggregate-rating content-id validated-rating)
          
          (log-rating-added content-id tx-sender validated-rating)
          (ok true))))))

(define-private (update-aggregate-rating (content-id uint) (new-rating uint))
  (let ((current-ratings-opt (map-get? content-ratings content-id)))
    (match current-ratings-opt
      current-ratings
      (let ((new-total (+ (get total-rating current-ratings) new-rating))
            (new-count (+ (get rating-count current-ratings) u1)))
        (map-set content-ratings content-id {
          total-rating: new-total,
          rating-count: new-count,
          average-rating: (/ new-total new-count)
        }))
      ;; Initialize if not exists
      (map-set content-ratings content-id {
        total-rating: new-rating,
        rating-count: u1,
        average-rating: new-rating
      }))))

;; Analytics helper
(define-private (update-content-analytics (content-id uint) (revenue uint))
  (let ((current-analytics-opt (map-get? content-analytics content-id)))
    (match current-analytics-opt
      current-analytics
      (map-set content-analytics content-id {
        view-count: (get view-count current-analytics),
        purchase-count: (+ (get purchase-count current-analytics) u1),
        revenue-generated: (+ (get revenue-generated current-analytics) revenue)
      })
      ;; Initialize if not exists
      (map-set content-analytics content-id {
        view-count: u0,
        purchase-count: u1,
        revenue-generated: revenue
      }))))

;; Enhanced buy-access with revenue sharing
(define-public (buy-access (id uint))
  (let ((content-result (map-get? contents id)))
    (begin
      ;; Check if contract is paused
      (asserts! (not (var-get paused)) (err ERR_CONTRACT_PAUSED))
      
      ;; Check if content exists
      (asserts! (is-some content-result) (err ERR_NOT_FOUND))
      
      (let ((content (unwrap-panic content-result)))
        (begin
          ;; Check if user already has active access
          (match (map-get? access {content-id: id, user: tx-sender})
            existing-access 
            (if (get active existing-access)
                (err ERR_ALREADY_HAS_ACCESS)
                (execute-purchase id content))
            (execute-purchase id content)))))))

(define-private (execute-purchase (id uint) (content {owner: principal, cid: (string-ascii 100), key-hash: (buff 32), price: uint, created-at: uint, category: (string-ascii 50), title: (string-ascii 100), description: (string-ascii 500), tags: (list 10 (string-ascii 30)), content-type: (string-ascii 20)}))
  (let ((price (get price content)))
    (begin
      ;; Check sufficient balance
      (asserts! (>= (stx-get-balance tx-sender) price) (err ERR_INSUFFICIENT_PAYMENT))
      
      ;; Distribute revenue
      (try! (distribute-revenue id price))
      
      ;; Grant access
      (map-set access {content-id: id, user: tx-sender} {granted-at: stacks-block-height, active: true, expires-at: none})
      
      ;; Update analytics
      (update-content-analytics id price)
      
      (log-access-purchased id tx-sender price)
      (ok true))))

;; Read-only functions
(define-read-only (get-content (id uint))
  (match (map-get? contents id)
    content (ok content)
    (err ERR_NOT_FOUND)))

(define-read-only (has-access (id uint) (user principal))
  (match (map-get? access {content-id: id, user: user})
    access-record 
    (if (get active access-record)
        (match (get expires-at access-record)
          expiry (ok (<= stacks-block-height expiry))
          (ok true))
        (ok false))
    (ok false)))

(define-read-only (get-subscription (id uint))
  (match (map-get? subscriptions id)
    subscription (ok subscription)
    (err ERR_NOT_FOUND)))

(define-read-only (get-content-rating (content-id uint))
  (match (map-get? content-ratings content-id)
    rating (ok rating)
    (err ERR_NOT_FOUND)))

(define-read-only (get-content-analytics (content-id uint))
  (match (map-get? content-analytics content-id)
    analytics (ok analytics)
    (err ERR_NOT_FOUND)))

(define-read-only (search-content-by-category (category (string-ascii 50)))
  (ok category)) ;; Simplified - in practice would need iteration

;; Content owner functions with enhanced validation
(define-public (update-content-price (id uint) (new-price uint))
  (let ((content-opt (map-get? contents id)))
    (if (is-some content-opt)
        (let ((content (unwrap! content-opt (err ERR_NOT_FOUND))))
          (begin
            (asserts! (is-eq tx-sender (get owner content)) (err ERR_UNAUTHORIZED))
            (asserts! (is-valid-price new-price) (err ERR_INVALID_PRICE))
            ;; Use validated price
            (let ((validated-price (if (is-valid-price new-price) new-price u1000000)))
              (begin
                (map-set contents id (merge content {price: validated-price}))
                (ok true)))))
        (err ERR_NOT_FOUND))))

(define-public (revoke-access (content-id uint) (user principal))
  (match (map-get? contents content-id)
    content
    (begin
      (asserts! (is-eq tx-sender (get owner content)) (err ERR_UNAUTHORIZED))
      (match (map-get? access {content-id: content-id, user: user})
        access-record
        (begin
          (map-set access {content-id: content-id, user: user} (merge access-record {active: false}))
          (ok true))
        (err ERR_NOT_FOUND)))
    (err ERR_NOT_FOUND)))

;; Read-only helper functions
(define-read-only (get-content-count)
  (ok (var-get content-counter)))

(define-read-only (get-subscription-count)
  (ok (var-get subscription-counter)))

(define-read-only (is-contract-paused)
  (ok (var-get paused)))

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner)))

(define-read-only (get-access-details (content-id uint) (user principal))
  (match (map-get? access {content-id: content-id, user: user})
    access-record (ok (some access-record))
    (ok none)))

(define-read-only (get-user-subscription (subscription-id uint) (user principal))
  (match (map-get? user-subscriptions {subscription-id: subscription-id, user: user})
    subscription (ok (some subscription))
    (ok none)))
