# Consultancy Tycoon — Game Design

An idle/incremental game where you grow from a solo freelance developer into a consulting empire. Built in Godot 4.6, 2D.

## Game Phases

Three phases that layer on top of each other — nothing is replaced:

1. **Clicker** — You sit at your desk, working in a fake IDE. Click through dev workflows to earn money.
2. **Semi-idle** — AI tools automate your coding loop (unreliably at first). You babysit and manually code when it matters.
3. **Idle/Management** — Hire consultants, build teams, place them on contracts. You can still personally take on contracts as the firm's best consultant for a premium "founder bonus."

The clicker never goes away. It becomes a strategic choice: grind a high-value contract yourself, or spend time optimizing your firm.

## Visual Style

A cozy office scene. Your monitor shows the fake IDE where clicker gameplay happens. The office has ambient details like a coffee maker. As the firm grows, the office expands with new desks and hires visible. The UI is light — the environment tells the story, not panels and dashboards.

## The Coding Loop (Phase 1)

The core clicker loop cycles through phases on the fake IDE:

1. **Get Task** — A task appears from your current client ("Fix authentication bug", "Add payment endpoint"). Difficulty and payout scale with client tier.
2. **Write Code** — Fake code snippets scroll as you click. Each click adds lines and fills a progress bar. Higher skills = more progress per click.
3. **Submit PR** — One click to submit. Brief animation.
4. **Code Review** — Reviewer comments appear on a diff view. Some approve (task advances), some request changes (click through fixes). Skill level affects approval ratio.
5. **Merge & Payout** — Task completes, you get paid.

**Random friction events** can insert extra steps:

- **Merge conflicts** — Occasional, not every task. A left/right diff appears, you pick the correct side. Wrong picks cost progress. Frequency decreases with higher skills.
- **Review rejections** — Change requests that require extra fix clicks. More common on contracts above your skill level.
- **CI failures** — Extra fix step. Requires DevOps skills to be in your skill tree to appear.

Taking contracts above your skill level increases all friction events for that contract's duration. The payout is better but the grind is real.

## Clients & Bidding

Clients appear periodically as notifications. Each contract shows:

- **Name and project type** ("FinApp wants a REST API refactor")
- **Required skills** with minimum levels
- **Payout** per task and number of tasks
- **Duration** before the offer expires

You click to bid. Success chance is weighted by your skills vs. requirements. You can bid below your level (high chance) or reach above (low chance, harder tasks if you land it).

### Contract Tiers

Unlock as reputation grows:

- **Freelance gigs** — Small one-off tasks. Low pay.
- **Short-term contracts** — Multiple tasks, decent pay.
- **Retainers** — Ongoing income, good pay.
- **SaaS contracts** — Recurring revenue. Premium tier. Eventually become passive income.

## Skill Tree & Certifications

Accessible from the desk area, outside the IDE. A visual tree or web of interconnected nodes.

### Skill Categories

- **Languages** — JavaScript, Python, Rust, Go, etc. Each unlocks new client types. Learning a "hot" language gives a temporary market demand bonus.
- **Frameworks & Tools** — React, Docker, Kubernetes, AWS. Prerequisites for higher-tier contracts.
- **Soft skills** — Communication, estimation, negotiation. Affect review approval rates, bidding success, and client satisfaction.

### How Skills Work

- Bought with money (course fees) or time (study instead of working — opportunity cost).
- Each skill has levels. Higher levels reduce friction on related tasks and unlock new contract types.
- Some skills are prerequisites for others (can't learn Kubernetes without Docker basics).

### Certifications

Milestone nodes in the tree. Expensive but give permanent stat boosts and unlock contract tiers. "AWS Certified" opens cloud migration contracts. "Scrum Master" is a prerequisite for hiring in phase 3.

### Efficiency Effects

- Higher coding language skill = more progress per click
- Framework knowledge = fewer review rejections on matching contracts
- DevOps skills = lower CI failure chance
- Soft skills = better bidding odds and review outcomes

## Random Events

Pop up as notifications in the office, not inside the IDE. Opportunities, not obstacles.

- **Conference talk invite** — Spend time preparing (can't work during prep). Completion gives a random reputation boost, bigger if skills match the topic.
- **Blog post goes viral** — Triggered by completing certain task types. Temporary influx of better client offers.
- **Open source contribution** — Side task with no direct pay. Gives skill XP and reputation.
- **Networking event** — Spend money to attend. Random chance to meet a high-value client or future hire.
- **Tech drama** — A framework gets controversial. Its contracts dry up, alternatives pay more. Rewards diversified skill trees.
- **Recruiter call** — Decline for a reputation boost, or accept as a soft prestige reset with cash bonus.

Events appear every few minutes of real time, never more than one at once. You can ignore them and they expire. As reputation grows, events become more impactful.

## AI Tools (Phase 2)

Purchasable from a "tools" menu on your desktop. Each automates part of the coding loop.

### Available Tools

- **Code Copilot** — Auto-progresses "write code." Starts ~30% reliable (buggy code triggers extra reviews). Upgradeable to ~90%.
- **Auto-reviewer** — Handles review feedback. Starts 50/50 whether fixes pass.
- **Merge resolver** — Auto-picks sides in conflicts. Coin-flip accuracy at first.
- **CI fixer** — Auto-retries CI failures. Only relevant with DevOps skills.

### Upgrade Path

Each tool has 3-5 upgrade tiers. Early tiers are cheap but unreliable. Top tiers are expensive but near-perfect.

### The Babysitting Phase

When AI tools mess up, you get a notification. You can manually fix it (faster) or let the AI retry (slower, might fail again). This creates the semi-idle feel — stepping away works, but checking in helps.

A fully upgraded AI pipeline earns less per task than doing it yourself (no founder bonus). But it frees you to manage consultants or personally handle premium contracts while AI grinds routine work.

## Hiring & Management (Phase 3)

Unlocked when you can afford office space. Scrum Master certification is a prerequisite. The office visually expands as you hire.

### Hiring

Consultants appear in a job market pool. Each has:

- Name and skill set
- Salary expectation
- Personality trait ("fast but sloppy", "slow but thorough", "flight risk", "perfectionist", "lone wolf")

Better consultants cost more. Your soft skills affect the quality of the available pool.

### Placement

Assign consultants to client contracts individually or as teams.

**Individual placement:** Match skills to contract requirements for max output. Mismatches earn less and risk complaints.

**Team placement (larger contracts, 2-5 people):** Build a roster. The team's combined skill set and trait mix determine output.

### Team Synergies

- **Complementary traits boost each other.** A perfectionist paired with a fast coder: the fast coder produces fewer bugs, the perfectionist speeds up. A senior with a junior accelerates the junior's skill growth.
- **Negative chemistry.** Two perfectionists slow each other in endless review loops. Two lone wolves reduce output.
- **Combined skills matter.** No DevOps person on the team? CI failures increase. A well-rounded team handles anything.
- **Discovery.** Synergies aren't known upfront. You discover them by trying combinations. Discovered synergies are recorded for future optimization.

### Management Issues

Consultants run their own invisible coding loop. You see income ticking and occasional problems:

- **Burnout** — Overworked consultant slows down. Give them a break or lose them.
- **Client complaint** — Skill mismatch or bad luck. Step in to smooth things over (costs your time) or risk losing the contract.
- **Consultant poached** — Competitor offers more money. Match or let them go.
- **Internal conflict** — Two consultants clash. Resolve it or both lose productivity.

### Your Role

You're the founder. Time splits between personally coding premium contracts (founder bonus), optimizing placements, building teams, and handling issues. The game becomes about time allocation.

## Prestige — Selling the Firm

When the firm reaches a threshold (revenue, headcount, or reputation), you can sell. You receive a legacy bonus based on firm value.

### What Carries Over

- Reputation (partial) — better starting clients
- Skill tree nodes unlocked at level 1 — faster re-skilling
- Discovered team synergies — you remember what works
- One permanent perk chosen at sale ("Industry Contacts" for better hires, "Brand Recognition" for faster bidding, "Patent Portfolio" for passive income from start)

### What Resets

- Money, office, consultants
- Skill levels (back to level 1 on unlocked nodes)
- AI tool upgrades
- Client contracts

Each run feels different because starting reputation opens different early clients, and the chosen perk shapes strategy.
