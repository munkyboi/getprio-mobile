# Notification inbox settings and summary

Notification preferences now live in a card at the top of the notification inbox, followed by inline Mark all as read / Empty inbox buttons, a divider, and unread/total counts. Profile no longer opens a notifications drawer. The existing authenticated queue-alert preference is preserved; failed saves retain the previous value and failed loads offer retry.

The inbox adapter accepts additive `totalCount`, the server's current count of all retained visible account notifications (read and unread), including pages not yet loaded. Read and clear actions refresh these counts. For older servers, total is derived only for an unpaginated first response; until then it displays a dash. Counts are not fabricated from a partial page.
