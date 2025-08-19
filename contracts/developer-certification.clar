;; Developer Certification and Qualification Management Contract
;; Manages developer skills, certifications, and qualification verification

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-DEVELOPER-NOT-FOUND (err u201))
(define-constant ERR-CERTIFICATION-NOT-FOUND (err u202))
(define-constant ERR-SKILL-NOT-FOUND (err u203))
(define-constant ERR-INVALID-INPUT (err u204))
(define-constant ERR-ALREADY-EXISTS (err u205))
(define-constant ERR-INVALID-RATING (err u206))
(define-constant ERR-CERTIFICATION-EXPIRED (err u207))
(define-constant ERR-INSUFFICIENT-EXPERIENCE (err u208))

;; Data Variables
(define-data-var next-certification-id uint u1)
(define-data-var next-skill-id uint u1)

;; Certification Status Constants
(define-constant CERT-ACTIVE u1)
(define-constant CERT-EXPIRED u2)
(define-constant CERT-REVOKED u3)
(define-constant CERT-PENDING u4)

;; Skill Level Constants
(define-constant SKILL-BEGINNER u1)
(define-constant SKILL-INTERMEDIATE u2)
(define-constant SKILL-ADVANCED u3)
(define-constant SKILL-EXPERT u4)

;; Experience Level Constants (in months)
(define-constant EXP-JUNIOR u12)
(define-constant EXP-MID u36)
(define-constant EXP-SENIOR u60)
(define-constant EXP-LEAD u96)

;; Data Maps
(define-map developers
  { developer: principal }
  {
    name: (string-ascii 50),
    email: (string-ascii 100),
    github-profile: (optional (string-ascii 100)),
    linkedin-profile: (optional (string-ascii 100)),
    total-experience-months: uint,
    reputation-score: uint,
    verified: bool,
    created-at: uint,
    updated-at: uint
  }
)

(define-map certifications
  { certification-id: uint }
  {
    developer: principal,
    technology: (string-ascii 50),
    certification-name: (string-ascii 100),
    issuing-authority: (string-ascii 100),
    issue-date: uint,
    expiry-date: (optional uint),
    status: uint,
    verification-hash: (buff 32),
    created-at: uint
  }
)

(define-map skills
  { skill-id: uint }
  {
    developer: principal,
    technology: (string-ascii 50),
    skill-name: (string-ascii 100),
    proficiency-level: uint,
    years-experience: uint,
    last-used: uint,
    verified-by: (optional principal),
    created-at: uint,
    updated-at: uint
  }
)

(define-map technology-ratings
  { developer: principal, technology: (string-ascii 50) }
  {
    overall-rating: uint,
    project-count: uint,
    total-rating-points: uint,
    last-updated: uint
  }
)

(define-map endorsements
  { endorser: principal, developer: principal, skill-id: uint }
  {
    rating: uint,
    comment: (optional (string-ascii 200)),
    created-at: uint
  }
)

(define-map verification-requests
  { developer: principal, verifier: principal }
  {
    requested-at: uint,
    status: uint,
    notes: (optional (string-ascii 300))
  }
)

;; Read-only functions
(define-read-only (get-developer (developer principal))
  (map-get? developers { developer: developer })
)

(define-read-only (get-certification (certification-id uint))
  (map-get? certifications { certification-id: certification-id })
)

(define-read-only (get-skill (skill-id uint))
  (map-get? skills { skill-id: skill-id })
)

(define-read-only (get-technology-rating (developer principal) (technology (string-ascii 50)))
  (map-get? technology-ratings { developer: developer, technology: technology })
)

(define-read-only (get-endorsement (endorser principal) (developer principal) (skill-id uint))
  (map-get? endorsements { endorser: endorser, developer: developer, skill-id: skill-id })
)

(define-read-only (get-verification-request (developer principal) (verifier principal))
  (map-get? verification-requests { developer: developer, verifier: verifier })
)

(define-read-only (get-next-certification-id)
  (var-get next-certification-id)
)

(define-read-only (get-next-skill-id)
  (var-get next-skill-id)
)

(define-read-only (is-developer-verified (developer principal))
  (match (get-developer developer)
    dev-data (get verified dev-data)
    false
  )
)

(define-read-only (get-developer-experience-level (developer principal))
  (match (get-developer developer)
    dev-data
    (let ((experience (get total-experience-months dev-data)))
      (if (>= experience EXP-LEAD)
        u4  ;; Lead level
        (if (>= experience EXP-SENIOR)
          u3  ;; Senior level
          (if (>= experience EXP-MID)
            u2  ;; Mid level
            u1  ;; Junior level
          )
        )
      )
    )
    u0  ;; Not found
  )
)

;; Private functions
(define-private (is-certification-valid (certification-id uint))
  (match (get-certification certification-id)
    cert-data
    (and
      (is-eq (get status cert-data) CERT-ACTIVE)
      (match (get expiry-date cert-data)
        expiry (> expiry block-height)
        true  ;; No expiry date means permanent
      )
    )
    false
  )
)

(define-private (calculate-reputation-score (developer principal))
  (match (get-developer developer)
    dev-data
    (let
      (
        (base-score (get total-experience-months dev-data))
        (cert-bonus u0)  ;; Could be calculated from active certifications
        (endorsement-bonus u0)  ;; Could be calculated from endorsements
      )
      (+ base-score cert-bonus endorsement-bonus)
    )
    u0
  )
)

(define-private (update-developer-timestamp (developer principal))
  (match (get-developer developer)
    dev-data
    (map-set developers
      { developer: developer }
      (merge dev-data { updated-at: block-height })
    )
    false
  )
)

;; Public functions
(define-public (register-developer
  (name (string-ascii 50))
  (email (string-ascii 100))
  (github-profile (optional (string-ascii 100)))
  (linkedin-profile (optional (string-ascii 100)))
  (total-experience-months uint)
)
  (let
    (
      (developer tx-sender)
    )
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len email) u0) ERR-INVALID-INPUT)
    (asserts! (is-none (get-developer developer)) ERR-ALREADY-EXISTS)

    ;; Register developer
    (map-set developers
      { developer: developer }
      {
        name: name,
        email: email,
        github-profile: github-profile,
        linkedin-profile: linkedin-profile,
        total-experience-months: total-experience-months,
        reputation-score: total-experience-months,
        verified: false,
        created-at: block-height,
        updated-at: block-height
      }
    )

    (ok true)
  )
)

(define-public (add-certification
  (technology (string-ascii 50))
  (certification-name (string-ascii 100))
  (issuing-authority (string-ascii 100))
  (issue-date uint)
  (expiry-date (optional uint))
  (verification-hash (buff 32))
)
  (let
    (
      (certification-id (var-get next-certification-id))
      (developer tx-sender)
    )
    (asserts! (is-some (get-developer developer)) ERR-DEVELOPER-NOT-FOUND)
    (asserts! (> (len technology) u0) ERR-INVALID-INPUT)
    (asserts! (> (len certification-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len issuing-authority) u0) ERR-INVALID-INPUT)
    (asserts! (<= issue-date block-height) ERR-INVALID-INPUT)

    ;; Add certification
    (map-set certifications
      { certification-id: certification-id }
      {
        developer: developer,
        technology: technology,
        certification-name: certification-name,
        issuing-authority: issuing-authority,
        issue-date: issue-date,
        expiry-date: expiry-date,
        status: CERT-ACTIVE,
        verification-hash: verification-hash,
        created-at: block-height
      }
    )

    ;; Update developer timestamp
    (update-developer-timestamp developer)

    ;; Increment certification ID
    (var-set next-certification-id (+ certification-id u1))

    (ok certification-id)
  )
)

(define-public (add-skill
  (technology (string-ascii 50))
  (skill-name (string-ascii 100))
  (proficiency-level uint)
  (years-experience uint)
)
  (let
    (
      (skill-id (var-get next-skill-id))
      (developer tx-sender)
    )
    (asserts! (is-some (get-developer developer)) ERR-DEVELOPER-NOT-FOUND)
    (asserts! (> (len technology) u0) ERR-INVALID-INPUT)
    (asserts! (> (len skill-name) u0) ERR-INVALID-INPUT)
    (asserts! (and (>= proficiency-level SKILL-BEGINNER) (<= proficiency-level SKILL-EXPERT)) ERR-INVALID-INPUT)
    (asserts! (> years-experience u0) ERR-INVALID-INPUT)

    ;; Add skill
    (map-set skills
      { skill-id: skill-id }
      {
        developer: developer,
        technology: technology,
        skill-name: skill-name,
        proficiency-level: proficiency-level,
        years-experience: years-experience,
        last-used: block-height,
        verified-by: none,
        created-at: block-height,
        updated-at: block-height
      }
    )

    ;; Update developer timestamp
    (update-developer-timestamp developer)

    ;; Increment skill ID
    (var-set next-skill-id (+ skill-id u1))

    (ok skill-id)
  )
)

(define-public (endorse-skill
  (developer principal)
  (skill-id uint)
  (rating uint)
  (comment (optional (string-ascii 200)))
)
  (let
    (
      (endorser tx-sender)
      (skill-data (unwrap! (get-skill skill-id) ERR-SKILL-NOT-FOUND))
    )
    (asserts! (is-eq (get developer skill-data) developer) ERR-INVALID-INPUT)
    (asserts! (not (is-eq endorser developer)) ERR-INVALID-INPUT)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-RATING)
    (asserts! (is-some (get-developer endorser)) ERR-DEVELOPER-NOT-FOUND)

    ;; Add endorsement
    (map-set endorsements
      { endorser: endorser, developer: developer, skill-id: skill-id }
      {
        rating: rating,
        comment: comment,
        created-at: block-height
      }
    )

    ;; Update technology rating
    (let
      (
        (technology (get technology skill-data))
        (current-rating (default-to
          { overall-rating: u0, project-count: u0, total-rating-points: u0, last-updated: u0 }
          (get-technology-rating developer technology)
        ))
        (new-total-points (+ (get total-rating-points current-rating) rating))
        (new-project-count (+ (get project-count current-rating) u1))
        (new-overall-rating (/ new-total-points new-project-count))
      )
      (map-set technology-ratings
        { developer: developer, technology: technology }
        {
          overall-rating: new-overall-rating,
          project-count: new-project-count,
          total-rating-points: new-total-points,
          last-updated: block-height
        }
      )
    )

    (ok true)
  )
)

(define-public (verify-developer (developer principal))
  (let
    (
      (verifier tx-sender)
      (dev-data (unwrap! (get-developer developer) ERR-DEVELOPER-NOT-FOUND))
    )
    (asserts! (is-some (get-developer verifier)) ERR-DEVELOPER-NOT-FOUND)
    (asserts! (not (is-eq verifier developer)) ERR-INVALID-INPUT)

    ;; Mark developer as verified
    (map-set developers
      { developer: developer }
      (merge dev-data {
        verified: true,
        updated-at: block-height
      })
    )

    ;; Record verification request
    (map-set verification-requests
      { developer: developer, verifier: verifier }
      {
        requested-at: block-height,
        status: u1,  ;; Approved
        notes: none
      }
    )

    (ok true)
  )
)

(define-public (update-skill-usage (skill-id uint))
  (let
    (
      (skill-data (unwrap! (get-skill skill-id) ERR-SKILL-NOT-FOUND))
      (developer (get developer skill-data))
    )
    (asserts! (is-eq tx-sender developer) ERR-NOT-AUTHORIZED)

    ;; Update last used timestamp
    (map-set skills
      { skill-id: skill-id }
      (merge skill-data {
        last-used: block-height,
        updated-at: block-height
      })
    )

    (ok true)
  )
)

(define-public (revoke-certification (certification-id uint))
  (let
    (
      (cert-data (unwrap! (get-certification certification-id) ERR-CERTIFICATION-NOT-FOUND))
    )
    (asserts! (or
      (is-eq tx-sender (get developer cert-data))
      (is-eq tx-sender CONTRACT-OWNER)
    ) ERR-NOT-AUTHORIZED)

    ;; Revoke certification
    (map-set certifications
      { certification-id: certification-id }
      (merge cert-data { status: CERT-REVOKED })
    )

    (ok true)
  )
)

(define-public (update-developer-experience (additional-months uint))
  (let
    (
      (developer tx-sender)
      (dev-data (unwrap! (get-developer developer) ERR-DEVELOPER-NOT-FOUND))
      (new-experience (+ (get total-experience-months dev-data) additional-months))
      (new-reputation (calculate-reputation-score developer))
    )
    (asserts! (> additional-months u0) ERR-INVALID-INPUT)

    ;; Update developer experience
    (map-set developers
      { developer: developer }
      (merge dev-data {
        total-experience-months: new-experience,
        reputation-score: new-reputation,
        updated-at: block-height
      })
    )

    (ok true)
  )
)
