# Principles

Every change to this app is held to these rules. Avokaido's Cloud Runner
quotes this file to the agent that builds a change, and its verifier judges
each pull request against every bullet below. One bullet is one rule, kept on
one line. A bullet tagged [critical] fails QA when a change breaks it; the
others take the severity the workspace sets.

## Every capability works end to end in the deployed app

- A capability is done when it works in the deployed app, not when it is wired. No stub, placeholder handler, TODO or faked success ships as the finished path of a capability.
- Every path of a capability is reachable from the app's own pages: a file that is uploaded can be downloaded and shown, a signed-in member can read what the rules allow, and mail that the app sends is actually sent.
- A change that lets the app store something also lets the people allowed to read it read it back, under the security rules as deployed (Storage rules that check Firestore, a query that needs an index).
- [critical] Whatever a capability needs outside the code is declared in this repository, so provisioning or the deploy sets it up: security rules, indexes, IAM roles, CORS, secrets and environment settings. Nothing is left for a person to set up by hand.

## Every error can be supported by an IT admin

- [critical] No error is swallowed. An empty catch, or a catch that turns a failure into a silent default without logging it, breaks this rule.
- An error is never only console.error, print or debugPrint. It is logged as one structured line through the app's logger: level, a short error reference, where it happened and what was being done.
- The error reference that is logged is also shown to the person who hit the error, so they can quote it to their IT admin and the admin can find the log line.
- [critical] Nothing secret or personal goes into a log line or an error message: no tokens, passwords, API keys, document or file contents, email addresses or names. Log an ID instead.
