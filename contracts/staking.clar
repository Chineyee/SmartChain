;; Staking Smart Contract
;; Allows users to stake tokens and earn rewards

;; Define token to be staked (reference to an existing token contract)
(define-constant token-contract .my-token) ;; Replace with actual token contract

;; Error codes
(define-constant err-not-owner (err u100))
(define-constant err-insufficient-funds (err u101))
(define-constant err-no-stake-found (err u102))
(define-constant err-invalid-amount (err u103))

;; Contract owner
(define-constant contract-owner tx-sender)

;; Staking rewards rate (reward per block per token staked, in microSTX)
(define-constant reward-rate u10) ;; 10 microSTX per block per token

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

;; Stake tokens
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
      (try! (claim-rewards))
      true)
    
    ;; Transfer tokens from user to contract
    (try! (contract-call? token-contract transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update stake information
    (map-set stakes tx-sender 
      { 
        amount: new-amount, 
        start-block: block-height, 
        last-claim-block: block-height 
      })
    (ok true))))

;; Unstake tokens
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
    
    ;; Transfer tokens from contract back to user
    (as-contract 
      (try! (contract-call? token-contract transfer amount tx-sender tx-sender none)))
    
    ;; Update stake information
    (map-set stakes tx-sender 
      { 
        amount: (- staked-amount amount), 
        start-block: block-height, 
        last-claim-block: block-height 
      })
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
    
    ;; Verify there are rewards to claim
    (asserts! (> reward-amount u0) (ok true))
    
    ;; Transfer rewards to user (in STX)
    (as-contract (stx-transfer? reward-amount tx-sender tx-sender))
    
    ;; Update last claim block
    (map-set stakes tx-sender 
      (merge stake-info { last-claim-block: block-height }))
    
    (ok reward-amount))))

;; Admin function to update reward rate (owner only)
(define-public (set-reward-rate (new-rate uint))
  (begin
    (asserts! (is-contract-owner) err-not-owner)
    (var-set reward-rate new-rate)
    (ok true)))