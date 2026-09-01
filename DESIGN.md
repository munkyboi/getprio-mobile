# GetPrio Customer Mobile Design Spec

## Editorial queue companion

GetPrio is a calm, editorial queue companion. The interface borrows the visual rhythm of a modern travel-discovery app: a warm paper canvas, confident serif titles, focused search and filters, expressive imagery, and clear journeys through a vertical progress timeline.

The travel reference is used for information hierarchy and interaction patterns only. Travel concepts are translated into GetPrio concepts: destinations become vendors, stays become locations and queues, bookings become queue joins, and itineraries become ticket progress. The product remains focused on customer queue flows.

Reference inspiration: [Sleek Travel App preview](https://sleek.design/templates/travel-app)

## Product scope

The customer app supports:

- Customer sign-in with email/password and OAuth2.
- Vendor discovery and queue-capable location browsing.
- QR-based queue joining from the raised center action or the empty Home state.
- Active and historical ticket management.
- Ticket cancellation while the ticket is waiting.
- Queue activity push notifications.
- Password, notification, security, and MFA settings.

Enterprise hosts, vendor administration, staff operations, payments administration, and non-queue vendor services are outside this mobile design scope.

## Design principles

### 1. Discover, then act

Explore should feel like browsing a curated directory. Search, filters, vendor identity, and queue availability should be visible before the customer commits to a location.

### 2. One obvious next action

GetPrio Orange is reserved for the next meaningful action: scan, join, confirm, or open a required payment step. Do not give every control equal emphasis.

### 3. Use surfaces sparingly

Cards are reserved for a primary active ticket, a tappable vendor/location item, or a high-value confirmation surface. Use dividers, whitespace, inline metrics, and list rows for secondary information. Do not nest cards inside cards or turn every section into a panel.

### 4. Make progress tangible

A customer should quickly understand ticket status, queue position, estimated wait, and what happens next. Use status badges, a progress indicator, and a simple vertical timeline when a ticket has meaningful events.

### 5. Keep the interface human

Warm paper, restrained shadows, friendly illustrations, and readable copy should make waiting feel dependable rather than clinical. Avoid glossy gradients, excessive decoration, and notification noise.

## Color system

### Brand colors

| Token | Value | Use |
| --- | --- | --- |
| GetPrio Orange | `#BB4D00` | Primary CTA, scan/join actions, active navigation, focus ring |
| Orange Strong | `#912F00` | Pressed primary state and strong orange emphasis |
| Queue Teal | `#0F766E` | Positive progress, open queues, confirmed and supporting actions |
| Queue Highlight | `#FFD166` | Wait-time or position emphasis; never use as a full-screen fill |

### Surfaces

| Token | Value | Use |
| --- | --- | --- |
| Paper Canvas | `#FBF7F1` | App background and navigation backdrop |
| Paper Accent | `#F2DFC9` | Empty states, filter groups, QR callouts, light highlights |
| Card White | `#FFFAF4` | Primary ticket surface, vendor rows, dialogs, and inputs |

### Text and structure

| Token | Value | Use |
| --- | --- | --- |
| GetPrio Ink | `#23180F` | Headings, ticket numbers, vendor names, primary text |
| Muted Ink | `#735F50` | Supporting copy, locations, timestamps, helper text |
| Warm Line | `#265F422A` | Dividers, input borders, quiet outlines |
| Disabled Ink | `#A8A096` | Disabled controls and unavailable placeholders |

### Functional colors

| Token | Value | Use |
| --- | --- | --- |
| Success | `#397A5A` | Successful joins and completed actions |
| Warning | `#B77932` | Delays, pending payment, expiring tickets |
| Destructive | `#B42318` | Cancellation, invalid credentials, failed requests |

Use orange for action, teal for calm positive progress, and destructive red only for actual failure or irreversible actions.

## Typography

### Typefaces

- **Display:** Georgia, weight 700–800. Use for screen titles, welcome moments, vendor names, and large ticket numbers.
- **UI:** Inter, weight 400–700. Use for navigation, buttons, labels, forms, badges, metadata, and explanatory copy.

### Type scale

| Style | Size · Weight · Line height | Use |
| --- | --- | --- |
| Display large | 36px · 800 · 1.10 | Auth welcome and major moments |
| Display | 32px · 800 · 1.15 | Home and ticket titles |
| Title | 26px · 800 · 1.20 | Vendor and detail titles |
| Heading | 22px · 800 · 1.25 | Section headings |
| Heading small | 18px · 700 · 1.30 | Card and status groups |
| Body large | 16px · 400 · 1.50 | Guidance and onboarding copy |
| Body | 14px · 400 · 1.50 | Standard content and vendor details |
| Label | 13px · 600 · 1.30 | Buttons, chips, badges, and form labels |
| Caption | 12px · 500 · 1.35 | Metadata and timestamps |
| Ticket | 30px · 800 · 1.10 | Ticket number and queue position |

## Spacing, shape, and elevation

- Base unit: 8px.
- Page inset: 20px.
- Compact inset: 12px.
- Primary surface inset: 20px; large QR/active-ticket surface inset: 24px.
- Related element gap: 12–16px.
- Major section gap: 28–36px.
- Minimum touch target: 44px.
- Card radius: 20px.
- Image radius: 16px.
- Input and button radius: 16px.
- Badge radius: 999px.
- Dialog radius: 24px.
- Content card shadow: `0 6px 24px rgba(91, 66, 42, 0.08)`.
- Active ticket shadow: `0 8px 28px rgba(187, 77, 0, 0.14)`.
- Primary action shadow: `0 4px 12px rgba(187, 77, 0, 0.20)`.

Prefer whitespace and warm dividers over additional containers.

On phone layouts, center action-button labels. Leading or trailing icons remain in their edge slots and must not shift the label away from the button's horizontal center. Larger tablet layouts may retain contextual alignment where it improves scanning.

## Navigation and information architecture

Use a stable five-item bottom navigation:

1. Home
2. Explore
3. Join Queue
4. Tickets
5. Account

`Join Queue` is the raised center action rather than a persistent content destination. Show only a large white QR icon inside the circular GetPrio Orange button. Place the `Join Queue` label outside and below the circle, using the same size and weight as the other navigation labels and GetPrio Orange for its color. Offset the circle above the bar. Activating it opens the camera scanner immediately with a clear back action and a short transition. Keep the Home “Scan to join” action as a second entry point when no ticket is active.

Distribute all five items across the full bar width with space between them. The active content destination uses GetPrio Orange on its icon and label without a filled background. Inactive destinations use warm ink or muted ink. Selection changes color only: do not change a navigation label's font size or weight between active and inactive states. Keep navigation reachable while customers monitor queue activity.

## Screen specifications

### Home

Purpose: show the customer’s next queue action at a glance.

Structure:

- Greeting using the customer display name, falling back to profile name.
- One short supporting sentence.
- One primary active-ticket surface. If empty, show the existing queue illustration, “No active tickets,” and the orange “Scan to join” action.
- If a ticket is active, show vendor, location, status, ticket number, position, estimated wait, and a route to join another queue.
- “Your stats” is an inline metrics row separated by a warm divider, not two separate cards.

Avoid promotional dashboard clutter. Sponsor or advertisement content, if added later, must remain secondary to the active queue.

### Explore

Purpose: help customers find a queue-capable vendor.

Structure:

- Serif title and brief discovery copy.
- Search field with `Search vendors` placeholder.
- Horizontal filter chips such as `All`, `Open now`, and vendor categories.
- Vendor results as tappable rows or restrained cards, showing name, category, location count, and queue availability.
- Empty, unavailable, loading, and retry states.

Use imagery or illustrations as a leading visual only when it helps identify the vendor. Do not force every result into a large photo card.

### Vendor detail

Purpose: explain the vendor and let the customer choose a queue-capable location.

Structure:

- Compact app bar with back and optional share/save actions.
- Hero illustration or vendor image with a 16px radius.
- Vendor name, category, and concise description.
- Highlights row for queue-relevant facts such as open locations, estimated wait, and operating hours.
- Location list with queue-open status, address, and a clear selection affordance.
- Direction to return Home and scan the location QR code to join.

Use a single surface for a selected location or important queue preview. Keep the location list lightweight.

### QR queue joining

Purpose: make the physical QR code the shortest path into a queue.

Flow:

1. Open the scan screen from the center `Join Queue` action or empty Home state.
2. Scan a trusted HTTPS vendor QR URL using `source=qr&id=<uuid>`.
3. Show the vendor/location and queue details for review.
4. Join a free queue immediately, or open secure hosted payment when required.
5. Show a confirmation state only after the server confirms the ticket.

The scan screen should use the queue illustration, a clear camera state, permission guidance, retry action, and an error state for invalid or unapproved hosts.

### Tickets

Purpose: manage the customer’s active and historical queue tickets.

Structure:

- Serif title and short explanation.
- Active ticket shown first with the ticket number, status, position, estimated wait, vendor, location, and notification state.
- Use a compact vertical timeline for meaningful events such as joined, called, served, or cancelled.
- Historical tickets use simple list rows with date, vendor, location, ticket number, and status.
- Cancellation uses an explicit confirmation dialog and destructive action.

Do not make every historical row a floating card; use dividers and grouped list sections.

### Account and security

Purpose: manage identity, notifications, and account safety.

Structure:

- Profile summary using display name first, then profile name fallback.
- Queue-alert toggle and notification preferences.
- Password and security settings.
- MFA setup, authenticator-code entry, recovery-code display, and confirmation.
- Log-out action separated from routine settings.

Use grouped settings rows with dividers. Reserve cards for the profile summary, security warning, or recovery-code protection surface.

## Component patterns

### Search and filter chips

Search is a full-width 16px-radius input. Filters are horizontally scrollable compact chips with a clear selected state. Selected filters use Queue Teal or a warm paper-accent fill; use orange only when the filter directly changes the next action.

### Queue status

- Waiting: Queue Teal.
- Called: GetPrio Orange.
- Served: Success green or Queue Teal.
- Pending or delayed: Warning brown.
- Cancelled, skipped, expired, or failed: Destructive red.
- Unknown or unavailable: muted outline.

### Progress timeline

Use a vertical line, small status markers, timestamps, and concise event labels. The current event is orange or teal; completed events are muted-success; future events remain warm neutral. Do not use a dense chart for a simple queue journey.

### Illustrations and imagery

Use the existing GetPrio illustrations for onboarding, empty dashboard, QR joining, and empty states. New vendor imagery should use warm, editorial crops inside 16px-radius containers. Never let imagery compete with the ticket number, status, or primary action.

## Interaction and system states

Every interactive component must define:

- Default, pressed, focused, disabled, and selected states.
- Loading state with stable layout dimensions.
- Empty state with one clear next action.
- Inline error state with retry where recovery is possible.
- Success state after server confirmation.
- Permission-denied and offline guidance for QR scanning and notifications.

Push notifications are supporting signals, not the sole source of truth. The ticket screen must refresh from the API when opened and after a queue event.

## Flutter implementation guidance

- Use Flutter with `shadcn_flutter` components.
- Keep the GetPrio tokens in `lib/app_theme.dart`.
- Apply component themes for cards, fields, buttons, badges, and navigation rather than styling each screen independently.
- Reuse existing API contracts and queue repositories.
- Keep new mobile-only API routes under `/backend/mobile/` only when an existing contract cannot support the flow.
- Preserve accessible labels for icons, QR actions, ticket status, and illustrations.
- Validate phone layouts first, then iPad portrait and landscape behavior.

## Definition of done for each screen

- Matches the color, type, spacing, and surface rules above.
- Has one clear primary action.
- Uses the minimum number of cards needed to explain hierarchy.
- Includes loading, empty, error, success, and disabled states where relevant.
- Keeps touch targets at least 44px.
- Works with long vendor names, locations, status labels, and translated copy.
- Has widget coverage for the primary interaction.
