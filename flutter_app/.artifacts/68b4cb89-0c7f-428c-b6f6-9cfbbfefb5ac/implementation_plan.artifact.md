# Implementation Plan: Fix Scrolling, Analytics Redesign & UI Polish

The goal is to fix the scrolling issue in the emulator, resolve the top bar overflow, and redesign the AI Insights tab to match the user's specific screenshot.

## User Review Required

> [!NOTE]
> I will be reverting some of the "Premium" design changes in the Analytics tab to match the exact "System Overview" layout you requested in the 3rd screenshot.

## Proposed Changes

### 1. Fix App Bar Overflow
- Wrap the app bar title `Column` in an `Expanded` widget.
- Reduce horizontal padding/spacing if necessary to fit the "Language Switcher" and "Logout" buttons on smaller emulator screens.

### 2. Redesign AI Insights Tab (Match Screenshot 3)
- **Grid Layout:** Implement a 2x2 grid of KPI tiles for ASHA Workers, Jurisdiction Areas, DB Status, and API Status.
- **Vitals Monitoring Card:** Create a specific card with:
    - Header: Red heartbeat icon + Title.
    - Divider.
    - Custom bullet point list using Unicode characters or small icons.
- **Container Styling:** Use the specific border and shadow style shown in the screenshot (clean white cards with rounded corners).

### 3. Fix Scrolling Issues
- Ensure each tab in the `TabBarView` has a proper scrollable root.
- In the Jurisdiction and ASHA Worker tabs, use a `NestedScrollView` or ensure the `Expanded(ListView)` is correctly constrained by the parent.
- Add `AlwaysScrollableScrollPhysics()` to ensure the emulator always registers drag gestures even if the list is short.

### 4. Jurisdiction Tab Cleanup
- Fix the Action Buttons row overflow by using a `Wrap` or ensuring they are sized correctly for the emulator screen.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no syntax regressions.

### Manual Verification
- **Scrolling:** Open the emulator and drag up/down on all three tabs.
- **Analytics:** Verify the 3rd tab looks identical to the provided screenshot.
- **Overflows:** Verify no red overflow bars appear on the app bar or jurisdiction buttons.
