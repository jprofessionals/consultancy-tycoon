# Management Rework — Design Document

Rework the management/hiring system from an overlay panel into its own full scene with a top-down office view, separated contract system, and consultant lifecycle management.

## Scene Structure & Navigation

The game has two distinct spaces connected by a door:

**Personal Office** (existing side-view desk scene) — Your coding workspace. Personal contracts, AI tools, skill purchases. The existing "management door" becomes a real scene transition instead of opening an overlay panel. All management UI (hiring panel, consultant assignment) is removed from this scene.

**Management Office** (new top-down view) — A bird's-eye open-plan office floor. All hiring, consultant management, and contract placement lives here. Consultants sit at desks with visual state indicators. Random chat bubbles float up with programming quips.

**Navigation** — Simple toggle. A door in the personal office transitions to the management office. A "Back to Desk" door in the management office returns you. Both spaces continue running in the background — AI tools keep coding while you manage, consultants keep working while you code. The HUD persists across both views.

**Expandable doors** — The management office has locked doors along the walls for future features (Team War Room, etc.). Locked doors show a lock icon and tooltip with the unlock requirement.

## Contract System

Management contracts are separate from personal contracts. The contract pool is split by tier:

- **Small contracts** — Personal only. Handled at your desk.
- **Mid-tier contracts** — Flexible. Can be taken personally or assigned to consultants.
- **Large contracts** — Team only. Unlocked later via the Team War Room door.

### Project Contracts

Mid and large-tier contracts with skill requirements, task counts, and payouts. Shorter duration than rentals. You assign consultants who meet the requirements, and they work through the project over time. Consultants return when the project ends.

### Consultant Rentals

Place a consultant at a client site for a long fixed duration. The client pays a steady rate. The consultant's desk appears empty while on rental. Longer duration than projects — the "set and forget" option for stable revenue.

### Rental Extensions

When a rental nears its end, a random chance triggers an extension opportunity. A notification appears in the management inbox. Responding lets you negotiate to increase the extension chance (picking the right response from options, spending reputation, etc.). Missing or ignoring the notification has no penalty — the consultant simply returns when the rental ends. Pure upside opportunity.

## Consultant Lifecycle & Economics

### Salary Drain

Every consultant has a salary that ticks continuously whether they're working or not. Idle consultants cost money without generating income. This creates pressure to keep staff utilized or let them go.

### Consultant States

| State | Location | Cost | Benefit |
|-------|----------|------|---------|
| **Idle** | In office (desk) | Salary | Very slow passive skill growth |
| **Training** | In office (desk) | Salary + training fees | Faster targeted skill growth |
| **Remote (idle)** | Off-site (no desk) | Salary | Slower passive skill growth than in-office |
| **Remote (training)** | Off-site (no desk) | Salary + training fees | Slower training than in-office, slight coordination penalty |
| **On Project** | Absent from office | Salary (offset by project earnings) | Earns revenue, returns when done |
| **On Rental** | Absent from office | Salary (offset by rental income) | Steady passive income |

### Capacity & Overhiring

- **Desk capacity** — Number of physical desks in the office. Determines how many can be in-office (idle or training at full speed).
- **Max staff** — Up to 3x desk capacity. Staff beyond desk count work remote (reduced training, coordination penalty) or must be placed on contracts/rentals.
- **Ideal distribution** — e.g., 4 desks: 4 in office training, 4 remote as bench, 4 out on rentals earning money.

### Hiring

- One-time recruitment fee + ongoing salary.
- Firing is immediate — salary stops, desk frees up. No severance (could add later).
- Rehiring is expensive, so plan ahead rather than churn.

### Economic Loop

Hire carefully, train strategically, keep utilization high. A well-run firm has most consultants placed on work with a few in training for upcoming needs. A poorly-run firm has idle staff draining cash — potentially leading to bankruptcy from overhiring.

## Hiring System

**Job market** — Accessible from a hiring board/screen on the office wall. Rotating pool of candidates that refreshes periodically. Good candidates don't stick around forever.

**Each candidate shows:**
- Name and avatar
- Skill set with levels (e.g., JavaScript 3, Python 2)
- Salary expectation (monthly drain)
- Recruitment fee (one-time)
- Personality trait ("fast but sloppy", "slow but thorough", etc.)

**Pool quality** — Influenced by firm reputation and soft skills. Low reputation gets junior candidates. High reputation attracts expensive senior specialists.

## Contract Board

**Management contract board** — A visible whiteboard/screen on the office wall. Shows available projects and rental opportunities.

**Each contract shows:**
- Client name and project type
- Required skills with minimum levels
- Duration (projects shorter, rentals longer)
- Payout (total for projects, rate for rentals)
- Capacity needed (how many consultants)

**Placement flow:** Select a contract, assign consultant(s) who meet the requirements, confirm. The consultant leaves the office and starts earning.

## Staff Roster

A dedicated panel (clipboard/HR screen on the wall) showing ALL consultants regardless of location:

- **In Office** — Current state (idle/training), skills, salary
- **Remote** — Current state (idle/training), skills, salary, reduced training indicator
- **On Project** — Which project, skills, time remaining, progress
- **On Rental** — Which client, skills, rental duration remaining, extension notification pending

Click any entry for full consultant details.

## Office Floor Visual Design

**Top-down view** of an open-plan office. Camera shows the full floor without scrolling (initially).

**Desk layout** — Desks arranged in clusters or rows. Each desk is a slot. Starting capacity: 4-6 desks. More desks through office upgrades or revenue milestones.

**Consultant visuals by state:**
- **Idle** — Sitting at desk, leaning back, scrolling phone. Occasional chat bubble.
- **Training** — Hunched over laptop with book/notes visible. Focused pose.
- **On contract/rental** — Desk is empty. Nameplate or "Out" sign.

**Remote consultants** — Not visible on the office floor. Only appear in the staff roster panel.

**Chat bubbles** — Random programming quips over idle and training consultants:
- "JavaScript really sucks"
- "I hate weak typing"
- "Who wrote this code... oh wait, it was me"
- "It works on my machine"
- "Have you tried turning it off and on again?"
- "This should only take 5 minutes..."

Bubbles fade after a few seconds. Purely cosmetic.

**Interactive objects:**
- **Consultant** — Click for details panel
- **Contract board** (whiteboard on wall) — Opens contract browser
- **Hiring board** (screen on wall) — Opens job market
- **Management inbox** (desk near entrance) — Rental extensions and notifications
- **Back to Desk door** — Returns to personal office
- **Locked doors** — Future features with lock icon and requirement tooltip

## What Changes in Existing Code

**Removed from personal office:**
- `HiringPanel` and its door trigger
- Consultant assignment flow in `main.gd`
- `[Team]` prefixed emails in personal inbox

**Stays untouched:**
- Personal office desk scene and IDE
- Small contracts in personal bidding panel
- EventBus and GameState autoloads (extended, not rewritten)
- Save/load system (extended for new data)

**New scenes/scripts:**
- `ManagementOffice` — Top-down scene with desk layout, walls, doors, objects
- `ConsultantSprite` — Visual consultant with state animations and chat bubbles
- `ContractBoard` — UI for management contracts (projects + rentals)
- `StaffRoster` — All-consultants panel with status/location
- `HiringBoard` — Reworked hiring UI
- `ManagementInbox` — Notifications for rental extensions and management events

**GameState additions:**
- Desk capacity and office level
- Consultant location tracking (in-office / remote / on-project / on-rental)
- Remote work state and penalties
- Active rentals with duration and extension state
- Management contract pool (separate from personal)

## Future Expansion (via locked doors)

- **Team War Room** — Unlocks team formation and large team-only contracts
- **Products & Solutions** — Teams build products (own IP, recurring revenue) or managed services (client-funded, steady income). Both can be continuously improved for more revenue.
- Additional rooms TBD
