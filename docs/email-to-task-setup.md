# Email-to-Task Setup

Forward any email to your Axis Reminders inbox in two clicks. No backend server needed — this rides on the existing `axis://reminder` URL handler and Apple's built-in Shortcuts + Mail rules.

## How it works

Axis exposes a URL scheme that creates a Reminder from a title:

```
axis://reminder?title=<encoded title here>
```

The title is run through `QuickAddParser`, so natural-language tokens (`tomorrow 5pm p1 #work`) get parsed into due date, priority, and labels automatically.

## One-time Shortcut

1. Open **Shortcuts.app** → tap **+** to create a new shortcut.
2. Add the action **Get Contents of Input** (set input type: *Mail messages*, *Text*).
3. Add **Text** → set its content to:
   ```
   Shortcut Input
   ```
   (Use the magic-variable picker to insert the message's subject.)
4. Add **URL** → set the URL to:
   ```
   axis://reminder?title=
   ```
5. Add **Combine Text** to concatenate the URL + URL-encoded subject. (Use the **URL Encode** action between them.)
6. Add **Open URLs** → input the combined URL.
7. Name the shortcut **Add to Axis** and pin it.

Now from any Mail message → Share Sheet → **Add to Axis** creates a reminder. Done.

## Hands-free Apple Mail rule

To auto-forward specific senders/keywords:

1. **Mail.app** → Preferences → **Rules** → Add Rule.
2. Condition: `From contains <your forwarding address>` (or `Subject contains [task]`).
3. Action: **Run AppleScript** → use the snippet below to fire the Shortcut.

```applescript
on perform_mail_action(theData)
    tell application "Mail"
        set selectedMessages to |SelectedMessages| of theData
        repeat with msg in selectedMessages
            set theSubject to subject of msg
            do shell script "shortcuts run 'Add to Axis' --input-path " & ¬
                quoted form of theSubject
        end repeat
    end tell
end perform_mail_action
```

Save the script under `~/Library/Application Scripts/com.apple.mail/`, then select it in the rule's *Run AppleScript* action.

## Verifying

Test by opening Safari and pasting:
```
axis://reminder?title=Test%20task%20tomorrow%205pm%20p1
```

You should be dropped into the Workflow tab with a new High-priority reminder due tomorrow at 5pm.

## Notes & limits

- The URL handler runs on the device that receives the URL, so this works wherever Shortcuts can run (iOS/iPadOS/macOS).
- Body parsing is not yet implemented — only the subject becomes the reminder title. If you want to capture body text into the reminder's notes, extend `axis://reminder` to accept a `&notes=` parameter in `AppReducer.swift` (search for `case "reminder":`).
- For a server-side forwarding address (`tasks@your-domain.com`), see `backend/` and wire SendGrid Inbound Parse to POST into a hosted endpoint that issues the same URL via APNs — out of scope for the local-only setup above.
