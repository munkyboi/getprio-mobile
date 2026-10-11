# Keyboard focus and scrolling audit — 11 October 2026

Scope: MAIN customer mobile app. Source audit covered every editable TextField/TextArea constructor and the shared OTP editor; readonly OTP display cells are intentionally excluded. This is source and automated coverage, not physical interaction proof for every field.

## Global rules

- GetPrioTheme.wrap overrides EditableTextTapOutsideIntent. Touching outside an input unfocuses its editor and dismisses the keyboard; text is retained. Input feature buttons remain in Flutter's tap region, and switching between fields still transfers focus normally.
- Shared scroll margin is 24 logical pixels, replacing the 96px bottom margin. Native caret visibility and minimal custom correction handle focus; a visible field is not repositioned merely to force it beside the keyboard.
- KeyboardAwareInput never adds keyboard-height padding. It only adjusts scrolling enough to reveal the current focused editor and ignores stale work after blur. Tall textareas use native caret revelation instead of alternating top/bottom alignment.
- A viewport reserves keyboard space once. Resizing Scaffolds handle standard screens. Bottom DrawerWrapper already reserves its keyboard padding: its descendants receive KeyboardResizedViewport and consumed bottom viewInsets, preventing duplicate drawer/form/scroll padding. Unresized overlays still use KeyboardAwareScrollView reservation.

## Field coverage

| Flow / fields | Findings and applied behavior |
| --- | --- |
| Login identifier, password, MFA OTP, recovery code | Shared fields and OTP consume global blur and 24px margin. Removed double-keyboard padding; repeated taps remain stable. |
| Registration name, username, email, password and email verification OTP | Resizing Scaffold and shared scrollable/inputs; no additional field padding. |
| Password reset email and password fields | Resizing screen, shared inputs and minimal correction. |
| Explore search | Removed duplicate keyboard inset from ListView padding; root Scaffold owns resize. |
| Profile personal name/display name/email/phone, password and verification OTP | Drawer owns keyboard space; removed profile container inset and disabled redundant inner reservation. |
| Security current/new/confirm password, MFA password/codes/recovery | Shared fields inside drawer or resizing screen; drawer reservation suppressed automatically. |
| Vendor contact subject and message textarea | Shared blur and margin; drawer reservation suppressed automatically. Existing explicit textarea unfocus remains compatible. |
| Vendor/ticket review multiline comment | Replaced 96px scroll margin with shared 24px margin; global blur and existing explicit unfocus apply. Unresized dialog scroll reservation retained. |
| Booking name/email/phone and verification OTP | Removed inner scroll keyboard padding; drawer consumes keyboard inset once. Drag dismiss remains enabled. |
| Manual payment reference | Native shadcn editor receives global blur, native 20px caret margin and resizing booking-details ListView. |
| Scan/join email verification OTP | Shared OTP editor, focus correction and scroll container; drawer reservation suppressed when embedded in drawer. |
| Account deletion password | Replaced 96px margin with shared 24px margin; global blur and minimal focused-editor correction. |

## Verification

New tests cover touch blur without data loss for text/password/textarea/OTP; resized screens and unresized overlays keep lower inputs near the keyboard and stable on repeated taps; a real bottom drawer reserves space once and reveals its lower input. Existing login tests retain repeated-tap and visibility checks. Two older fixtures now set physical size and device pixel ratio consistently, so keyboard and viewport measurements use the same coordinate space. Boundary checks require the full field above the keyboard without forcing an oversized gap.

All 365 tests pass; Flutter analysis is clean. Signed MAIN production-configured Profile build succeeds. Device install/launch results are recorded on KanbanFlow. Physical keyboard animation, predictive-text keyboard heights and all-screen interaction review remain pending on Zero32 and Zero32 Domain.
