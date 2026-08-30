# GetPrio Customer Mobile

This context defines the customer-facing language for the GetPrio mobile app. It covers discovering vendors, joining live queues, and managing queue tickets.

## Language

**Customer**:
A person using GetPrio to join and manage their own queue tickets.
_Avoid_: Client, user when referring to the person in the product domain

**Display name**:
The customer-facing name shown on a queue ticket when the customer has provided one.
_Avoid_: Nickname, alias

**Profile name**:
The customer’s saved account name used when no display name is available.
_Avoid_: Legal name, username

**Vendor**:
A business or service provider that operates one or more GetPrio queues.
_Avoid_: Merchant, provider when referring to the business in the product domain

**Location**:
A specific branch or service site operated by a vendor where a queue is available.
_Avoid_: Branch when the product needs a customer-facing term

**Queue**:
A vendor location’s ordered list of customers waiting for service during its operating period.
_Avoid_: Line, booking queue

**Queue join**:
The customer action that creates a queue ticket for a selected vendor location.
_Avoid_: Reservation, booking

**Queue ticket**:
The customer’s record and place in one vendor location’s live queue, with a lifecycle status and queue position while waiting.
_Avoid_: Queue entry, booking, appointment

**Active queue ticket**:
A queue ticket whose lifecycle is still relevant to the customer, including waiting, called, or carry-over states.
_Avoid_: Current ticket when historical tickets are also visible

**Queue ticket status**:
The server-authoritative lifecycle state of a queue ticket. The mobile app presents the status and its customer meaning; it does not infer a new status from notification delivery or local time.
_Avoid_: Progress, stage when referring to the persisted ticket state

**Queue position**:
The ticket's one-based place among currently waiting tickets for its queue day. It is available only while the ticket is waiting and is not a permanent ticket number.
_Avoid_: Ticket number, rank

**Estimated wait**:
An approximate number of minutes returned with a waiting ticket's current position. It is a planning estimate, not a service-time promise or a guarantee of being served before closing.
_Avoid_: Appointment time, guarantee
