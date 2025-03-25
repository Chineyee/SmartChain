;; Staking Smart Contract
;; Simple staking mechanism using STX instead of custom tokens

;; Error codes
(define-constant err-not-owner (err u100))
(define-constant err-insufficient-funds (err u101))
(define-constant err-no-stake-found (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-minimum-stake (err u104))
(define-constant err-cooldown-active (err u105))
(define-constant err-early-withdrawal-fee (err u106))
(define-constant err-emergency-shutdown (err u107))
(define-constant err-cooldown-cancel (err u108))
(define-constant err-invalid-parameter (err u200))
(define-constant err-unauthorized-user (err u201))

;; Contract owner
(define-constant contract-owner tx-sender)

;; Staking rewards rate (reward per block per STX staked, in microSTX)
(define-data-var reward-rate uint u10) ;; 10 microSTX per block per STX

;; Data vars and maps

;; Track contract state
(define-data-var emergency-shutdown bool false)
(define-data-var minimum-stake uint u1000000) ;; 1 STX minimum (in microSTX)
(define-data-var early-withdrawal-fee-percent uint u10) ;; 10% fee
(define-data-var staking-cooldown-blocks uint u144) ;; ~1 day cooldown at 10 min blocks

;; Data maps to track stakes and rewards
(define-map stakes
  principal
  { 
    amount: uint, 
    start-block: uint, 
    last-claim-block: uint,
    cooldown-start: (optional uint)
  })

;; Data var to track total staked amount
(define-data-var total-staked-amount uint u0)

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner))

;; Check if principal is valid
(define-private (is-valid-principal (user principal))
  (not (is-eq user tx-sender)))

;; Get current stake info for a user
(define-read-only (get-stake-info (user principal))
  (default-to
    { amount: u0, start-block: u0, last-claim-block: u0, cooldown-start: none }
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
    (* (* staked-amount blocks-since-claim) (var-get reward-rate))
    u0)))

;; Start cooldown process for unstaking
(define-public (start-unstake-cooldown)
  (let (
    (stake-info (get-stake-info tx-sender))
    (staked-amount (get amount stake-info))
  )
  (begin
    ;; Verify stake exists
    (asserts! (> staked-amount u0) err-no-stake-found)
    
    ;; Claim any pending rewards first
    (try! (claim-rewards))
    
    ;; Set cooldown start block
    (map-set stakes tx-sender 
      (merge stake-info { cooldown-start: (some block-height) }))
    
    (ok block-height))))

;; Check if cooldown is complete
(define-read-only (is-cooldown-complete (user principal))
  (let (
    (stake-info (get-stake-info user))
    (cooldown-start (get cooldown-start stake-info))
  )
  (match cooldown-start
    cooldown-block (>= block-height (+ cooldown-block (var-get staking-cooldown-blocks)))
    false)))

;; Cancel unstake cooldown
(define-public (cancel-unstake-cooldown)
  (let (
    (stake-info (get-stake-info tx-sender))
    (cooldown-start (get cooldown-start stake-info))
  )
  (begin
    ;; Verify cooldown is active
    (asserts! (is-some cooldown-start) err-cooldown-cancel)
    
    ;; Reset cooldown
    (map-set stakes tx-sender 
      (merge stake-info { cooldown-start: none }))
    
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

;; Admin functions

;; Update reward rate (owner only)
(define-public (set-reward-rate (new-rate uint))
  (begin
    (asserts! (is-contract-owner) err-not-owner)
    ;; Add validation to ensure new-rate is reasonable
    (asserts! (< new-rate u1000) err-invalid-parameter) ;; Limit to reasonable value
    (var-set reward-rate new-rate)
    (ok true)))

;; Update minimum stake (owner only)
(define-public (set-minimum-stake (new-minimum uint))
  (begin
    (asserts! (is-contract-owner) err-not-owner)
    ;; Add validation for reasonable minimum stake
    (asserts! (>= new-minimum u100000) err-invalid-parameter) ;; At least 0.1 STX
    (var-set minimum-stake new-minimum)
    (ok true)))

;; Update early withdrawal fee (owner only)
(define-public (set-early-withdrawal-fee (new-fee-percent uint))
  (begin
    (asserts! (is-contract-owner) err-not-owner)
    (asserts! (<= new-fee-percent u100) err-invalid-parameter)
    (var-set early-withdrawal-fee-percent new-fee-percent)
    (ok true)))

;; Update staking cooldown period (owner only)
(define-public (set-staking-cooldown (new-cooldown-blocks uint))
  (begin
    (asserts! (is-contract-owner) err-not-owner)
    ;; Add validation for reasonable cooldown period
    (asserts! (<= new-cooldown-blocks u5760) err-invalid-parameter) ;; Max ~40 days at 10 min blocks
    (var-set staking-cooldown-blocks new-cooldown-blocks)
    (ok true)))

;; Emergency shutdown toggle (owner only)
(define-public (toggle-emergency-shutdown)
  (begin
    (asserts! (is-contract-owner) err-not-owner)
    (var-set emergency-shutdown (not (var-get emergency-shutdown)))
    (ok (var-get emergency-shutdown))))

;; Force withdraw for users in emergency (owner only)
(define-public (emergency-withdraw (user principal))
  (let (
    (stake-info (get-stake-info user))
    (staked-amount (get amount stake-info))
  )
  (begin
    ;; Verify emergency mode is active
    (asserts! (var-get emergency-shutdown) err-emergency-shutdown)
    
    ;; Verify owner is calling
    (asserts! (is-contract-owner) err-not-owner)
    
    ;; Verify stake exists
    (asserts! (> staked-amount u0) err-no-stake-found)
    
    ;; Validate the user principal
    (asserts! (is-valid-principal user) err-unauthorized-user)
    
    ;; Transfer full amount back to user
    (as-contract 
      (try! (stx-transfer? staked-amount tx-sender user)))
    
    ;; Update stake information
    (map-set stakes user 
      { 
        amount: u0, 
        start-block: block-height, 
        last-claim-block: block-height,
        cooldown-start: none
      })
    
    ;; Update total staked amount
    (var-set total-staked-amount (- (var-get total-staked-amount) staked-amount))
    (ok staked-amount))))

;; Read-only functions for contract stats

;; Get contract info
(define-read-only (get-contract-info)
  {
    reward-rate: (var-get reward-rate),
    total-staked: (var-get total-staked-amount),
    minimum-stake: (var-get minimum-stake),
    early-withdrawal-fee: (var-get early-withdrawal-fee-percent),
    cooldown-blocks: (var-get staking-cooldown-blocks),
    emergency-mode: (var-get emergency-shutdown)
  })

;; Get user-specific data
(define-read-only (get-user-info (user principal))
  (let (
    (stake-info (get-stake-info user))
    (pending-rewards (get-pending-rewards user))
    (cooldown-complete (is-cooldown-complete user))
  )
  {
    staked-amount: (get amount stake-info),
    stake-start-block: (get start-block stake-info),
    last-claim-block: (get last-claim-block stake-info),
    cooldown-status: (match (get cooldown-start stake-info)
                       cooldown-start { 
                         started: true, 
                         start-block: cooldown-start, 
                         complete: cooldown-complete
                       }
                       { started: false, start-block: u0, complete: false }),
    pending-rewards: pending-rewards
  }))

;; Calculate time remaining in cooldown
(define-read-only (get-cooldown-remaining (user principal))
  (let (
    (stake-info (get-stake-info user))
    (cooldown-start (get cooldown-start stake-info))
  )
  (match cooldown-start
    start-block (let (
                  (elapsed (- block-height start-block))
                  (total-cooldown (var-get staking-cooldown-blocks))
                )
                (if (>= elapsed total-cooldown)
                  u0
                  (- total-cooldown elapsed)))
    u0)))