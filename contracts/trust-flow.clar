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