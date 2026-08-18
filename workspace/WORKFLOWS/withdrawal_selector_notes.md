# LinkedIn Withdrawal Selector Notes

Working page:

```text
https://www.linkedin.com/mynetwork/invitation-manager/sent/
```

## Confirmed selectors

### Sent invitation row container

Purpose: scopes all actions to exactly one sent invitation row.

Validated strategy:

```js
const findInvitationRow = (withdrawLink) => {
  let node = withdrawLink.parentElement;
  while (node && node !== document.body) {
    const text = (node.innerText || node.textContent || "").replace(/\s+/g, " ").trim();
    const profileLinks = [...node.querySelectorAll('a[href*="/in/"]')].filter(visible);
    const rowWithdraws = [...node.querySelectorAll('a[aria-label^="Withdraw invitation sent to"]')].filter(visible);
    const rect = node.getBoundingClientRect();
    const area = Math.round(rect.width * rect.height);
    if (profileLinks.length === 1 && rowWithdraws.length === 1 && /sent/i.test(text) && area > 10000) {
      return node;
    }
    node = node.parentElement;
  }
  return null;
};
```

Observed row characteristics:

```text
row tag: DIV
row contains exactly one visible profile link
row contains exactly one visible list-level withdraw link
row text shape: <Name> <Title/company text> Sent <time> Withdraw
```

Do not click profile links or withdraw links from the whole page. First resolve the row, then query inside that row.

### Sent invitations scroll surface

Purpose: progressively loads all sent invitation rows.

Window scrolling did not move the sent invitations list. The actual scroll container is:

```js
document.querySelector("main#workspace")
```

Observed scroll container:

```text
tag: MAIN
id: workspace
overflow-y: scroll
initial visible withdraw links: 20
displayed people count: 185
```

Validated behavior:

- Updating `main#workspace.scrollTop` scrolls the invitations list.
- After progressive scrolling to the bottom, the DOM retained all loaded rows.
- Probe result after scrolling:

```json
{
  "scrollTop": 17284,
  "scrollHeight": 18228,
  "visibleWithdrawCount": 185,
  "capturedRows": 185
}
```

Runtime capture strategy:

```js
const scroller = document.querySelector("main#workspace");
scroller.scrollTop = 0;
// collect visible rows
// scroll scroller by a page
// wait for render
// collect again
// repeat until target rows are found or scroll bottom/stagnation cap is reached
```

For full-page inventory, progressive scroll can capture all loaded invitations. For runtime withdrawals, prefer target-aware scrolling: collect rows, match against prepared target LinkedIn URLs, act on matches, and keep scrolling until the batch targets are resolved or exhausted.

### Row-scoped profile navigation

Purpose: opens the invitee's profile from the sent invitation row, usually by clicking the profile picture link.

Validated row-scoped selector:

```js
row.querySelector('a[href*="/in/"]')
```

Observed element:

```text
tag: A
href: https://www.linkedin.com/in/<profile-slug>/
text: blank
aria-label: blank
contains image: true
image alt: <Name>'s profile picture
```

Probe results confirmed 10 visible rows each had:

```text
profileLinkCount: 1
hasImage: true
profileHref: https://www.linkedin.com/in/...
```

Runtime strategy:

```js
const profileLink = row.querySelector('a[href*="/in/"]');
profileLink.click();
```

### Sent invitation list withdraw control

Purpose: opens the withdrawal confirmation modal for one sent invitation.

Observed element:

```text
tag: A
text: Withdraw
aria-label: Withdraw invitation sent to <Name>
```

Selector:

```js
a[aria-label^="Withdraw invitation sent to"]
```

Notes:

- This selector should be used only for opening the modal.
- Prefer row-scoped usage:

```js
row.querySelector('a[aria-label^="Withdraw invitation sent to"]')
```

- The page appears to lazy-load invitations; do not assume all sent invitations are present in the DOM at once.
- Probe showed only 10 visible withdraw links even though the page count displayed 185 people.

### Modal confirm withdrawal control

Purpose: confirms the withdrawal action inside the modal.

Observed element:

```text
tag: BUTTON
text: Withdraw
aria-label: Withdraw invitation sent to <Name>
type: button
```

Selector:

```js
button[aria-label^="Withdraw invitation sent to"]
```

Notes:

- This selector performs the actual withdrawal.
- The important safety distinction is `A` versus `BUTTON`:
  - `A` opens the modal.
  - `BUTTON` confirms the withdrawal.

### Modal cancel control

Purpose: closes the confirmation modal without withdrawing.

Observed element:

```text
tag: BUTTON
text: Cancel
type: button
```

Selector approach:

```js
[...document.querySelectorAll("button")]
  .find((button) => button.innerText.trim() === "Cancel")
```

### Modal dismiss control

Purpose: closes the confirmation modal without withdrawing.

Observed element:

```text
tag: BUTTON
aria-label: Dismiss
type: button
```

Selector:

```js
button[aria-label="Dismiss"]
```

## Current validated flow

1. On the sent invitations page, click:

```js
a[aria-label^="Withdraw invitation sent to"]
```

2. Confirm modal appears with title:

```text
Withdraw invitation
```

3. Modal contains warning copy indicating another invitation cannot be sent to that person for up to 3 weeks.

4. Modal confirm button is:

```js
button[aria-label^="Withdraw invitation sent to"]
```

5. Modal can be safely closed with either:

```js
button[aria-label="Dismiss"]
```

or the visible `Cancel` button.

## Still to probe

- How to reliably match a prepared target LinkedIn URL/name to a visible sent-invitation row after URL normalization.
- Post-confirmation success signal:
  - toast text,
  - row disappearance,
  - button disappearance,
  - page count decrement,
  - or another reliable DOM state.
- Failure states:
  - already withdrawn,
  - not found in sent invitations,
  - modal confirmation fails,
  - LinkedIn restriction/checkpoint/login/captcha.
