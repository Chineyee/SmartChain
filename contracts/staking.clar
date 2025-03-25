;; Staking Smart Contract
;; Simple staking mechanism using STX instead of custom tokens

;; Error codes
(define-constant err-not-owner (err u100))
(define-constant err-insufficient-funds (err u101))
(define-constant err-no-stake-found (err u102))
(define-constant err-invalid-amount (err u103))

;; Contract owner
(define-constant contract-owner tx-sender)

;; Staking rewards rate (reward per block per STX staked, in microSTX)
(define-constant reward-rate u10) ;; 10 microSTX per block per STX

;; Data maps to track stakes and rewards
(define-map stakes
  principal
  { amount: uint, start-block: uint, last-claim-block: uint })

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner))

;; Get current stake info for a user
(define-read-only (get-stake-info (user principal))
  (default-to
    { amount: u0, start-block: u0, last-claim-block: u0 }
    (map-get? stakes user)))

;; Calculate pending rewards for a user
(define-read-only (get-pending-rewards (user principal))
  (let (
    (stake-info (get-stake-info user))
    (staked-amount (get amount stake-info))
    (last-claim (get last-claim-block stake-info))
    (current-block block-height)
    (blocks-since-claim (- current-block last-claim))
  )
  (if (> staked-amount u0)
    (* (* staked-amount blocks-since-claim) reward-rate)
    u0)))

;; Stake STX
(define-public (stake (amount uint))
  (let (
    (current-stake (get-stake-info tx-sender))
    (current-amount (get amount current-stake))
    (new-amount (+ amount current-amount))
  )
  (begin
    ;; Check amount is valid
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Claim any pending rewards first
    (if (> current-amount u0)
      (begin
        (try! (claim-rewards))
        true)
      true)
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update stake information
    (map-set stakes tx-sender 
      { 
        amount: new-amount, 
        start-block: block-height, 
        last-claim-block: block-height 
      })
    
    ;; Update total staked amount
    (var-set total-staked-amount (+ (var-get total-staked-amount) amount))
    (ok true))))

;; Unstake STX
(define-public (unstake (amount uint))
  (let (
    (stake-info (get-stake-info tx-sender))
    (staked-amount (get amount stake-info))
  )
  (begin
    ;; Verify stake exists and is sufficient
    (asserts! (>= staked-amount amount) err-insufficient-funds)
    
    ;; Claim any pending rewards first
    (try! (claim-rewards))
    
    ;; Transfer STX from contract back to user
    (as-contract 
      (try! (stx-transfer? amount tx-sender tx-sender)))
    
    ;; Update stake information
    (map-set stakes tx-sender 
      { 
        amount: (- staked-amount amount), 
        start-block: block-height, 
        last-claim-block: block-height 
      })
    
    ;; Update total staked amount
    (var-set total-staked-amount (- (var-get total-staked-amount) amount))
    (ok true))))

;; Claim staking rewards
(define-public (claim-rewards)
  (let (
    (reward-amount (get-pending-rewards tx-sender))
    (stake-info (get-stake-info tx-sender))
    (staked-amount (get amount stake-info))
  )
  (begin
    ;; Verify user has a stake
    (asserts! (> staked-amount u0) err-no-stake-found)
    
    (if (> reward-amount u0)
      (begin
        ;; Transfer rewards to user (in STX)
        (try! (as-contract (stx-transfer? reward-amount tx-sender tx-sender)))
        
        ;; Update last claim block
        (map-set stakes tx-sender 
          (merge stake-info { last-claim-block: block-height }))
        
        (ok reward-amount))
      (begin
        ;; Just update the last claim block if no rewards
        (map-set stakes tx-sender 
          (merge stake-info { last-claim-block: block-height }))
        (ok u0)))
  )))

;; Admin function to update reward rate (owner only)
(define-public (set-reward-rate (new-rate uint))
  (begin
    (asserts! (is-contract-owner) err-not-owner)
    (ok true)))

;; Get contract info
(define-read-only (get-contract-info)
  {
    reward-rate: reward-rate,
    total-staked: (var-get total-staked-amount)
  })

;; Data var to track total staked amount
(define-data-var total-staked-amount uint u0)