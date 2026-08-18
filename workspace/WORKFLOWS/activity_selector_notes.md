# Activity Selector Notes

Purpose: collect validated LinkedIn selectors for the standalone Pre-final activity checker before wiring selector-based navigation into runtime.

## Validated: Profile Activity Entry

Use case:
- From a normal LinkedIn profile page, click through to the activity page instead of opening the activity URL directly.

Primary selector:
```js
a[aria-label="Show all posts"][href*="/recent-activity/all/"]
```

Fallback selectors:
```js
a[href*="/recent-activity/all/"]
a[aria-label="Show all posts"]
```

Validated on:
- Profile: `https://www.linkedin.com/in/julie-curry-msw-7b054539b`
- Click target: `https://www.linkedin.com/in/julie-curry-msw-7b054539b/recent-activity/all/`

Probe result:
```json
[
  {
    "selector": "a[aria-label=\"Show all posts\"][href*=\"/recent-activity/all/\"]",
    "visibleMatches": 1
  },
  {
    "selector": "a[href*=\"/recent-activity/all/\"]",
    "visibleMatches": 1
  },
  {
    "selector": "a[aria-label=\"Show all posts\"]",
    "visibleMatches": 1
  }
]
```

Click test result:
```json
{
  "ok": true,
  "clickedHref": "https://www.linkedin.com/in/julie-curry-msw-7b054539b/recent-activity/all/"
}
```

Runtime notes:
- Prefer the primary selector.
- After clicking, wait for either:
  - `location.href.includes("/recent-activity/all/")`, or
  - activity tab controls become visible.
- Do not hardcode full profile-specific hrefs.

## Still To Validate

- Reactions dropdown path when Reactions is hidden.
- Optional Love reaction path.

## Validated: Activity Tabs

Use case:
- After landing on a LinkedIn profile activity page, switch between activity tabs.

Observed controls:
```json
[
  {
    "tag": "BUTTON",
    "text": "Posts",
    "aria": ""
  },
  {
    "tag": "BUTTON",
    "text": "Comments",
    "aria": ""
  },
  {
    "tag": "BUTTON",
    "text": "Reactions",
    "aria": ""
  }
]
```

Recommended runtime strategy:
- Find visible `button`, `[role="tab"]`, `[role="menuitem"]`, or `a` elements whose normalized visible text exactly matches:
  - `Posts`
  - `Comments`
  - `Reactions`
- Prefer exact visible text over class names.
- If `Reactions` is not visible, open a nearby `More` or overflow menu and retry the same exact-text search.

Selector-style probes:
```js
[...document.querySelectorAll("button, a, [role='tab'], [role='menuitem']")]
  .filter(el => (el.innerText || el.textContent || "").replace(/\s+/g, " ").trim() === "Posts")
```

```js
[...document.querySelectorAll("button, a, [role='tab'], [role='menuitem']")]
  .filter(el => (el.innerText || el.textContent || "").replace(/\s+/g, " ").trim() === "Comments")
```

```js
[...document.querySelectorAll("button, a, [role='tab'], [role='menuitem']")]
  .filter(el => (el.innerText || el.textContent || "").replace(/\s+/g, " ").trim() === "Reactions")
```

## Validated: Visible Post Reaction Controls

Use case:
- Detect visible reaction count buttons, Like buttons, and the reactions menu on visible activity posts.

Observed repeated controls:
```json
[
  {
    "tag": "BUTTON",
    "text": "76",
    "aria": "76 reactions"
  },
  {
    "tag": "BUTTON",
    "text": "Like",
    "aria": "React Like",
    "pressed": "false"
  },
  {
    "tag": "BUTTON",
    "text": "",
    "aria": "Open reactions menu"
  }
]
```

Recommended runtime selectors:
```js
button[aria-label="React Like"][aria-pressed="false"]
```

```js
button[aria-label="Open reactions menu"]
```

```js
button[aria-label$=" reactions"]
```

Runtime notes:
- These controls repeat once per visible post/card.
- Scope reaction actions to the chosen post card before clicking.
- For the first version, prefer `React Like` over richer reactions unless a separate Love path is validated.
- Treat `aria-pressed="true"` as already reacted and skip.

Additional probe observation:
- A broad dropdown probe returned many `button[aria-label="Open reactions menu"]` controls and reaction-count links such as `18 reactions`, `27 reactions`, etc.
- That confirms the per-post reaction menu selector, but it does not validate the activity-tab overflow path because the results were mostly post-level controls.

## Remaining Validation

- Love reaction path after opening `Open reactions menu`.

## Validated: Activity Tab More Overflow Button

Use case:
- On an activity page where `Reactions` is hidden, open the activity tab overflow menu beside `Posts` and `Comments`.

Observed DOM shape:
```html
<button
  aria-pressed="false"
  aria-expanded="false"
  id="overflow-button-ember74"
  type="button"
  class="profile-creator-shared-pills__pill artdeco-pill artdeco-pill--slate artdeco-pill--choice artdeco-pill--3 artdeco-pill--toggle"
>
  <span class="artdeco-pill__text">More</span>
</button>
```

Recommended selector candidates:
```js
button[id^="overflow-button-"][aria-expanded]
```

```js
button.profile-creator-shared-pills__pill[aria-expanded]
```

Runtime notes:
- Do not hardcode the full `overflow-button-ember74` id because the numeric suffix is session/page specific.
- Prefer a visible button whose normalized text is exactly `More` and whose `id` starts with `overflow-button-`.
- After clicking, wait for a visible dropdown item named `Reactions`.
- Do not rely on `aria-expanded` as the only open-state signal; LinkedIn kept it as `"false"` in a confirmed successful click test.

Probe result:
```json
[
  {
    "isMore": true,
    "tag": "BUTTON",
    "text": "More"
  }
]
```

Click test result:
```json
{
  "ok": true,
  "id": "overflow-button-ember74",
  "text": "More",
  "aria": "",
  "expandedAfterClick": "false"
}
```

Follow-up menu probe result:
```json
[]
```

Confirmed click result:
```json
{
  "ok": true,
  "clickedMore": {
    "text": "More",
    "id": "overflow-button-ember68"
  },
  "beforeUrl": "https://www.linkedin.com/in/ryanadamgray/recent-activity/all/",
  "afterUrl": "https://www.linkedin.com/in/ryanadamgray/recent-activity/reactions/",
  "urlChanged": true
}
```

Current conclusion:
- The selector correctly finds the activity-tab `More` button.
- A human-style DOM click opened the dropdown and allowed the hidden `Reactions` item to be clicked.
- The reliable success signal is either visible dropdown items after the click or a final URL/tab state change after selecting the item.

## Validated: Activity More Dropdown Items

Use case:
- After opening the activity-tab `More` dropdown, click hidden activity collection options such as `Reactions`.

Observed visible dropdown labels:
- `Videos`
- `Images`
- `Articles`
- `Documents`
- `Reactions`

Observed DOM shape:
```html
<div
  role="button"
  id="content-collection-pill-6"
  class="artdeco-dropdown__item artdeco-dropdown__item--is-dropdown ember-view"
  tabindex="0"
>
  Reactions
</div>
```

Recommended runtime selector candidates:
```js
div[role="button"][id^="content-collection-pill-"]
```

```js
.artdeco-dropdown__item[role="button"]
```

Runtime selection rule:
- After opening activity `More`, find a visible dropdown item whose normalized text is exactly `Reactions`.
- Do not hardcode the full `content-collection-pill-6` id; the suffix can vary with page/session.
- Click the element itself, not only a child span.

Validated probe result:
```json
[
  {
    "text": "Videos",
    "id": "content-collection-pill-2",
    "role": "button"
  },
  {
    "text": "Images",
    "id": "content-collection-pill-3",
    "role": "button"
  },
  {
    "text": "Articles",
    "id": "content-collection-pill-4",
    "role": "button"
  },
  {
    "text": "Documents",
    "id": "content-collection-pill-5",
    "role": "button"
  },
  {
    "text": "Reactions",
    "id": "content-collection-pill-6",
    "role": "button"
  }
]
```

Confirmed click result:
```json
{
  "ok": true,
  "clickedReactions": {
    "text": "Reactions",
    "id": "content-collection-pill-6",
    "role": "button"
  },
  "beforeUrl": "https://www.linkedin.com/in/ryanadamgray/recent-activity/all/",
  "afterUrl": "https://www.linkedin.com/in/ryanadamgray/recent-activity/reactions/",
  "urlChanged": true
}
```

Current conclusion:
- The hidden `Reactions` activity tab path is validated:
  1. click activity-tab `More`
  2. find visible `.artdeco-dropdown__item[role="button"]`
  3. click the item whose text is exactly `Reactions`
  4. verify navigation by checking for `/recent-activity/reactions/` or the selected `Reactions` tab state
