# Queue Discovery Design QA

## Evidence

- Redundant join-screen reference: `/tmp/codex-remote-attachments/01a0464d-0966-7b53-a588-8784afd86325/CFA50982-5230-4547-B816-23461DF473FD/1-Pasted-Image-1.jpg`
- Explore-screen reference: `/tmp/codex-remote-attachments/01a0464d-0966-7b53-a588-8784afd86325/CFA50982-5230-4547-B816-23461DF473FD/2-Pasted-Image-2.jpg`
- Implementation screenshot: `.design-qa/explore-after.png`
- Normalized source-versus-implementation comparison: `.design-qa/explore-source-vs-after.png`
- Viewport: iPhone 17 Pro Max simulator, 440 × 956 logical points, device pixel ratio 3.
- State: light theme, Explore selected, representative queue-capable vendors, two real vendor profile images and one fallback.

## Full-view comparison

The Explore reference and implementation were reviewed side by side at the same 591 × 1280 display size. The implementation preserves GetPrio's warm-paper palette, filters, five-item navigation, elevated Join Queue action, and card hierarchy while replacing generic store placeholders with vendor profile media. The typography is intentionally quieter than the source: smaller display headings, lighter heading weight, tighter card names, and less aggressive negative tracking.

## Behavior evidence

- Home's scan action opens `QrScannerPage` directly.
- The center `Join Queue` navigation action uses the same direct scanner route.
- Cancelling checkout and choosing `Scan another QR code` reopen the scanner directly.
- The removed `Join a queue` introduction screen is absent from all four paths.
- Camera permission denial stays inside the scanner, explains the Settings recovery step, and returns to the launching tab through `Go back`.
- Widget tests cover the direct routes so the redundant screen cannot return unnoticed.

## Required fidelity surfaces

- Typography: display sizes are now 32/28/20/17 with weight 700 and gentler tracking; body and navigation text retain their established sizes and selected-state weight.
- Spacing and rhythm: search, filters, directory rows, and bottom navigation retain consistent phone margins and touch targets.
- Colors and tokens: warm paper, ink, orange primary, teal status, and warm dividers continue to use the shared GetPrio theme.
- Images and assets: directory rows use API-provided `logoUrl`, then `imageUrl`, with the configured fit and a branded GetPrio fallback.
- Copy and content: vendor name, category, queue-capable location count, and availability remain fully visible.
- Icons and accessibility: media has vendor-specific semantic labels; navigation and status semantics remain unchanged.
- States and interactions: image load failures recover to the branded fallback and direct scan routes preserve checkout/ticket state transitions.

## Findings

- No actionable P0, P1, or P2 findings remain.
- [P3] Real profile media varies in visual style and crop. The application respects each vendor's configured fit and falls back safely when an asset fails.

## Comparison history

### Before — blocked

- [P1] Every directory card used the same generic storefront icon, hiding the vendor's identity.
- [P1] Queue joining stopped at a redundant explanatory screen before opening the scanner.
- [P2] 36/32/22 display sizes, weight 800, and strong negative tracking made the interface feel overly brutalist.

### After — passed

- Vendor profile media is visible in the directory with resilient fallback behavior.
- Join entry, retry, and checkout-cancel paths open the camera scanner directly.
- The side-by-side comparison confirms a calmer hierarchy without weakening readability or GetPrio branding.

final result: passed
