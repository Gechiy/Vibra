;; Define the Music Track NFT
(define-non-fungible-token track-id uint)

;; Define the releases map
(define-map track-releases
  {track-id: uint}
  {producer: principal, release-price: uint, released-at: uint})

;; Define the producer royalties map
(define-map producer-royalties
  {track-id: uint}
  {original-producer: principal, royalty-split: uint})

;; Define the studio manager
(define-data-var studio-manager principal tx-sender)

;; Define studio state (for maintenance functionality)
(define-data-var studio-offline bool false)

;; Define constants
(define-constant TRACK_MIN_PRICE u1)
(define-constant TRACK_MAX_PRICE u1000000000) ;; 1 billion microSTX
(define-constant MAX_ROYALTY_SPLIT u30) ;; 30%
(define-constant RELEASE_MODIFICATION_COOLDOWN u86400) ;; 24 hours in seconds
(define-constant STUDIO_OWNER tx-sender)
(define-constant MAX_TRACK_NUMBER u1000000) ;; Maximum allowed track ID

;; Error codes
(define-constant ERR_TRACK_NOT_AVAILABLE (err u101)) 
(define-constant ERR_INSUFFICIENT_STX (err u102)) 
(define-constant ERR_PURCHASE_FAILED (err u103)) 
(define-constant ERR_INVALID_ROYALTY_SPLIT (err u104)) 
(define-constant ERR_UNAUTHORIZED_ACCESS (err u105)) 
(define-constant ERR_CANNOT_PURCHASE_OWN_TRACK (err u106)) 
(define-constant ERR_INVALID_TRACK_PRICE (err u107)) 
(define-constant ERR_MODIFICATION_COOLDOWN (err u108)) 
(define-constant ERR_STUDIO_MAINTENANCE (err u109)) 
(define-constant ERR_TRACK_ALREADY_RELEASED (err u110)) 
(define-constant ERR_INVALID_TRACK_NUMBER (err u111)) 
(define-constant ERR_INVALID_MANAGER (err u112)) 

;; Helper function to validate track ID
(define-private (validate-track-number (track-num uint))
  (and 
    (>= track-num u0)
    (<= track-num MAX_TRACK_NUMBER)))

;; Helper function to validate manager
(define-private (validate-manager (new-manager principal))
  (and 
    (not (is-eq new-manager STUDIO_OWNER))
    (not (is-eq new-manager (var-get studio-manager)))))

;; Administrative Functions

(define-public (appoint-studio-manager (new-manager principal))
  (begin
    (asserts! (is-eq tx-sender STUDIO_OWNER) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (validate-manager new-manager) ERR_INVALID_MANAGER)
    (var-set studio-manager new-manager)
    (print {event: "studio-manager-appointed", new-manager: new-manager})
    (ok true)))

(define-public (toggle-studio-maintenance)
  (begin
    (asserts! (is-eq tx-sender (var-get studio-manager)) ERR_UNAUTHORIZED_ACCESS)
    (ok (var-set studio-offline (not (var-get studio-offline))))))

;; Helper Functions

(define-read-only (is-track-available (track-num uint))
  (is-some (map-get? track-releases {track-id: track-num})))

(define-read-only (get-track-release-info (track-num uint))
  (map-get? track-releases {track-id: track-num}))

(define-read-only (calculate-royalty-payment (price uint) (split uint))
  (/ (* price split) u100))

(define-read-only (get-producer-royalty-info (track-num uint))
  (default-to {original-producer: tx-sender, royalty-split: u0}
    (map-get? producer-royalties {track-id: track-num})))

;; Core Functions

(define-public (studio-mint (track-num uint) (royalty-split uint))
  (begin
    (asserts! (not (var-get studio-offline)) ERR_STUDIO_MAINTENANCE)
    (asserts! (validate-track-number track-num) ERR_INVALID_TRACK_NUMBER)
    (asserts! (is-none (nft-get-owner? track-id track-num)) (err u500))
    (asserts! (<= royalty-split MAX_ROYALTY_SPLIT) ERR_INVALID_ROYALTY_SPLIT)
    (try! (nft-mint? track-id track-num tx-sender))
    (map-set producer-royalties
      {track-id: track-num}
      {original-producer: tx-sender, royalty-split: royalty-split})
    (print {event: "track-minted", track-num: track-num, producer: tx-sender})
    (ok true)))

(define-public (studio-release (track-num uint) (release-price uint))
  (let ((owner (nft-get-owner? track-id track-num)))
    (begin
      (asserts! (not (var-get studio-offline)) ERR_STUDIO_MAINTENANCE)
      (asserts! (validate-track-number track-num) ERR_INVALID_TRACK_NUMBER)
      (asserts! (is-some owner) (err u205)) 
      (asserts! (is-eq (some tx-sender) owner) (err u201)) 
      (asserts! (and (>= release-price TRACK_MIN_PRICE) (<= release-price TRACK_MAX_PRICE)) ERR_INVALID_TRACK_PRICE)
      (asserts! (not (is-track-available track-num)) ERR_TRACK_ALREADY_RELEASED)
      (map-set track-releases
        {track-id: track-num}
        {producer: tx-sender, release-price: release-price, released-at: stacks-block-height})
      (print {event: "track-released", track-num: track-num, price: release-price, producer: tx-sender})
      (ok true))))

(define-public (modify-release-price (track-num uint) (updated-price uint))
  (let (
    (release (unwrap! (map-get? track-releases {track-id: track-num}) ERR_TRACK_NOT_AVAILABLE))
    (current-height stacks-block-height)
  )
    (begin
      (asserts! (not (var-get studio-offline)) ERR_STUDIO_MAINTENANCE)
      (asserts! (validate-track-number track-num) ERR_INVALID_TRACK_NUMBER)
      (asserts! (is-eq tx-sender (get producer release)) ERR_UNAUTHORIZED_ACCESS)
      (asserts! (and (>= updated-price TRACK_MIN_PRICE) (<= updated-price TRACK_MAX_PRICE)) ERR_INVALID_TRACK_PRICE)
      (asserts! (>= (- current-height (get released-at release)) RELEASE_MODIFICATION_COOLDOWN) ERR_MODIFICATION_COOLDOWN)
      (map-set track-releases
        {track-id: track-num}
        {producer: tx-sender, release-price: updated-price, released-at: current-height})
      (print {event: "release-price-modified", track-num: track-num, updated-price: updated-price})
      (ok true))))

(define-public (withdraw-from-release (track-num uint))
  (let ((release (unwrap! (map-get? track-releases {track-id: track-num}) ERR_TRACK_NOT_AVAILABLE)))
    (begin
      (asserts! (not (var-get studio-offline)) ERR_STUDIO_MAINTENANCE)
      (asserts! (validate-track-number track-num) ERR_INVALID_TRACK_NUMBER)
      (asserts! (is-eq tx-sender (get producer release)) ERR_UNAUTHORIZED_ACCESS)
      (map-delete track-releases {track-id: track-num})
      (print {event: "track-withdrawn-from-release", track-num: track-num})
      (ok true))))

(define-public (studio-purchase (track-num uint))
  (let (
    (release (unwrap! (map-get? track-releases {track-id: track-num}) ERR_TRACK_NOT_AVAILABLE))
    (royalty-info (default-to {original-producer: tx-sender, royalty-split: u0} 
      (map-get? producer-royalties {track-id: track-num})))
    (buyer tx-sender)
    (seller (get producer release))
  )
    (begin
      (asserts! (not (var-get studio-offline)) ERR_STUDIO_MAINTENANCE)
      (asserts! (validate-track-number track-num) ERR_INVALID_TRACK_NUMBER)
      (asserts! (not (is-eq buyer seller)) ERR_CANNOT_PURCHASE_OWN_TRACK)
      (asserts! (is-some (nft-get-owner? track-id track-num)) (err u209)) 
      (let (
        (price (get release-price release))
        (royalty-payment (calculate-royalty-payment price (get royalty-split royalty-info)))
        (seller-payment (- price royalty-payment))
      )
        (asserts! (>= (stx-get-balance buyer) price) ERR_INSUFFICIENT_STX)
        ;; Transfer royalty to original producer if applicable
        (if (> royalty-payment u0)
          (try! (stx-transfer? royalty-payment buyer (get original-producer royalty-info)))
          true)
        ;; Transfer remaining amount to seller
        (try! (stx-transfer? seller-payment buyer seller))
        ;; Transfer NFT to buyer
        (match (nft-transfer? track-id track-num seller buyer)
          success (begin
            (map-delete track-releases {track-id: track-num})
            (print {
              event: "track-purchased",
              track-num: track-num,
              buyer: buyer,
              seller: seller,
              price: price,
              royalty: royalty-payment
            })
            (ok true))
          error (begin
            (try! (stx-transfer? price seller buyer))
            ERR_PURCHASE_FAILED))))))

(define-public (transfer-track (track-num uint) (recipient principal))
  (let ((owner (nft-get-owner? track-id track-num)))
    (begin
      (asserts! (not (var-get studio-offline)) ERR_STUDIO_MAINTENANCE)
      (asserts! (validate-track-number track-num) ERR_INVALID_TRACK_NUMBER)
      (asserts! (is-some owner) (err u206)) 
      (asserts! (is-eq (some tx-sender) owner) (err u204)) 
      (asserts! (not (is-eq recipient tx-sender)) ERR_CANNOT_PURCHASE_OWN_TRACK)
      (try! (nft-transfer? track-id track-num tx-sender recipient))
      (print {event: "track-transferred", track-num: track-num, from: tx-sender, to: recipient})
      (ok true)))) 

 