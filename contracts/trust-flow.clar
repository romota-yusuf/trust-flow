;; Title: TrustFlow - Dynamic Credit Lending Protocol
;;
;; Summary: Revolutionary peer-to-peer lending platform with adaptive risk assessment
;; and reputation-based loan qualification system built on Bitcoin's Layer 2.
;;
;; Description:
;; TrustFlow reimagines decentralized finance by introducing an intelligent credit 
;; ecosystem that evolves with user behavior. Through sophisticated reputation tracking
;; and risk-adjusted collateral requirements, borrowers earn enhanced lending privileges
;; while maintaining protocol security. The system dynamically adjusts interest rates
;; and collateral ratios based on proven creditworthiness, creating a sustainable
;; lending marketplace that rewards responsible financial behavior while protecting
;; the ecosystem from default risks.
;;
;; Key Features:
;; - Adaptive collateral requirements (50-100% based on reputation)
;; - Dynamic interest rate pricing (5-10% APR)
;; - Progressive credit scoring system (50-100 points)
;; - Multi-loan portfolio management
;; - Automated default detection and liquidation
;; - Bitcoin-native security model

;; PROTOCOL CONSTANTS

(define-constant CONTRACT-OWNER tx-sender)

;; Error Codes
(define-constant ERR-UNAUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-BALANCE (err u2))
(define-constant ERR-INVALID-AMOUNT (err u3))
(define-constant ERR-LOAN-NOT-FOUND (err u4))
(define-constant ERR-LOAN-DEFAULTED (err u5))
(define-constant ERR-INSUFFICIENT-SCORE (err u6))
(define-constant ERR-ACTIVE-LOAN (err u7))
(define-constant ERR-NOT-DUE (err u8))
(define-constant ERR-INVALID-DURATION (err u9))
(define-constant ERR-INVALID-LOAN-ID (err u10))

;; Credit Scoring Parameters
(define-constant MIN-SCORE u50)
(define-constant MAX-SCORE u100)
(define-constant MIN-LOAN-SCORE u70)

;; DATA STRUCTURES

;; User Reputation and Credit History
(define-map UserScores
  { user: principal }
  {
    score: uint,
    total-borrowed: uint,
    total-repaid: uint,
    loans-taken: uint,
    loans-repaid: uint,
    last-update: uint,
  }
)

;; Loan Registry
(define-map Loans
  { loan-id: uint }
  {
    borrower: principal,
    amount: uint,
    collateral: uint,
    due-height: uint,
    interest-rate: uint,
    is-active: bool,
    is-defaulted: bool,
    repaid-amount: uint,
  }
)

;; User Loan Portfolio Tracking
(define-map UserLoans
  { user: principal }
  { active-loans: (list 20 uint) }
)

;; PROTOCOL STATE VARIABLES

(define-data-var next-loan-id uint u0)
(define-data-var total-stx-locked uint u0)

;; PUBLIC INTERFACE FUNCTIONS

;; Initialize Credit Profile
;; Creates a new credit profile for first-time users
(define-public (initialize-score)
  (let ((sender tx-sender))
    (asserts! (is-none (map-get? UserScores { user: sender })) ERR-UNAUTHORIZED)
    (ok (map-set UserScores { user: sender } {
      score: MIN-SCORE,
      total-borrowed: u0,
      total-repaid: u0,
      loans-taken: u0,
      loans-repaid: u0,
      last-update: stacks-block-height,
    }))
  )
)

;; Request New Loan
;; Submits a loan application with specified parameters
(define-public (request-loan
    (amount uint)
    (collateral uint)
    (duration uint)
  )
  (let (
      (sender tx-sender)
      (loan-id (+ (var-get next-loan-id) u1))
      (user-score (unwrap! (map-get? UserScores { user: sender }) ERR-UNAUTHORIZED))
      (active-loans (default-to { active-loans: (list) } (map-get? UserLoans { user: sender })))
    )
    ;; Validate loan application
    (asserts! (>= (get score user-score) MIN-LOAN-SCORE) ERR-INSUFFICIENT-SCORE)
    (asserts! (<= (len (get active-loans active-loans)) u5) ERR-ACTIVE-LOAN)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (and (> duration u0) (<= duration u52560)) ERR-INVALID-DURATION)
    ;; Calculate risk-adjusted collateral requirement
    (let ((required-collateral (calculate-required-collateral amount (get score user-score))))
      (asserts! (>= collateral required-collateral) ERR-INSUFFICIENT-BALANCE)
      ;; Secure collateral in contract
      (try! (stx-transfer? collateral sender (as-contract tx-sender)))
      ;; Create loan record
      (map-set Loans { loan-id: loan-id } {
        borrower: sender,
        amount: amount,
        collateral: collateral,
        due-height: (+ stacks-block-height duration),
        interest-rate: (calculate-interest-rate (get score user-score)),
        is-active: true,
        is-defaulted: false,
        repaid-amount: u0,
      })
      ;; Update user's loan portfolio
      (try! (update-user-loans sender loan-id))
      ;; Disburse loan funds
      (as-contract (try! (stx-transfer? amount tx-sender sender)))
      ;; Update protocol state
      (var-set next-loan-id loan-id)
      (var-set total-stx-locked (+ (var-get total-stx-locked) collateral))
      (ok loan-id)
    )
  )
)

;; Process Loan Repayment
;; Handles partial or full loan repayments
(define-public (repay-loan
    (loan-id uint)
    (amount uint)
  )
  (let (
      (sender tx-sender)
      (loan (unwrap! (map-get? Loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
    )
    ;; Validate repayment request
    (asserts! (is-eq sender (get borrower loan)) ERR-UNAUTHORIZED)
    (asserts! (get is-active loan) ERR-LOAN-NOT-FOUND)
    (asserts! (not (get is-defaulted loan)) ERR-LOAN-DEFAULTED)
    (asserts! (<= loan-id (var-get next-loan-id)) ERR-INVALID-LOAN-ID)
    ;; Calculate total outstanding debt
    (let ((total-due (calculate-total-due loan)))
      (asserts! (>= amount u0) ERR-INVALID-AMOUNT)
      ;; Process repayment
      (try! (stx-transfer? amount sender (as-contract tx-sender)))
      ;; Update loan status
      (let ((new-repaid-amount (+ (get repaid-amount loan) amount)))
