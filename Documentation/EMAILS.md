# Making BlockTopia emails look and feel right
Firebase sends the emails, so their *body* is limited to plain text, but the page people land on is fully ours.

## 1. Point email links at BlockTopia's own pages (this is the big upgrade)
Firebase Console > Authentication > **Templates**. For **Email address verification**, **Password reset** and **Email address change**:
1. Click the pencil icon.
2. **Customize action URL** -> `https://YOURNAME.github.io/BlockTopia/pages/action.html`
3. Save. Links now open `pages/action.html`, which shows a branded confirmation / new-password screen instead of Firebase's plain default page.

`pages/verify.html` is the "Check your inbox" screen shown right after sign up (resend button with cooldown, auto-continues once verified).

## 2. Template text (paste into each template)
**Sender name:** BlockTopia  **Reply-to:** your support address (Settings > Project settings > Public-facing name: BlockTopia)

*Verify email* - Subject: `Confirm your BlockTopia account`
```
Hi %DISPLAY_NAME%,

Welcome to BlockTopia! Tap the link below to confirm your email and start playing Baseplate.

%LINK%

This link works for one hour. If you didn't create a BlockTopia account, you can ignore this email.

- The BlockTopia team
```
*Password reset* - Subject: `Reset your BlockTopia password`
```
Hi,

We got a request to reset the password for %EMAIL%. Choose a new one here:

%LINK%

Didn't ask for this? Ignore this email: your password stays the same.

- The BlockTopia team
```
## 3. Honest limits
Firebase does not allow custom HTML or a logo inside these emails on the free Spark plan. For fully designed HTML emails you need to send them yourself (Firebase Admin SDK `generateEmailVerificationLink` + an email service such as Resend/SendGrid) from the Backend.
