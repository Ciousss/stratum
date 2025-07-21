# Stratum Smart Contract

A decentralized content platform for Stacks, supporting content registration, access control, subscriptions, revenue sharing, analytics, and ratings.

---

## Features

- **Content Registration:**  
  Register content with rich metadata (category, title, description, tags, type).

- **Access Control:**  
  Users can buy access to content. Owners can revoke access.

- **Subscriptions:**  
  Content owners can create subscription tiers. Users can purchase subscriptions for time-limited access.

- **Revenue Sharing:**  
  Owners can set up revenue splits among multiple recipients.

- **Ratings & Reviews:**  
  Users can rate and review content they have access to. Aggregate ratings are tracked.

- **Analytics:**  
  Tracks views, purchases, and revenue for each content item.

- **Admin Controls:**  
  Contract owner can pause/unpause the contract and transfer ownership.

---

## Data Structures

- **Maps:**  
  - `contents`: Stores content metadata.
  - `access`: Tracks user access to content.
  - `subscriptions`: Subscription tier details.
  - `user-subscriptions`: User subscription records.
  - `revenue-splits`: Revenue split configuration.
  - `content-ratings`: Aggregate ratings.
  - `user-ratings`: Individual user ratings.
  - `content-analytics`: Content analytics.

- **Variables:**  
  - `content-counter`: Content ID counter.
  - `subscription-counter`: Subscription ID counter.
  - `contract-owner`: Owner of the contract.
  - `paused`: Contract pause state.

---

## Key Functions

### Public Functions

- `register-content`: Register new content with metadata.
- `register-content-simple`: Register content with minimal info.
- `buy-access`: Purchase access to content.
- `create-subscription`: Create a subscription tier for content.
- `buy-subscription`: Purchase a subscription.
- `rate-content`: Rate and review content.
- `setup-revenue-split`: Configure revenue sharing for content.
- `update-content-price`: Update price of owned content.
- `revoke-access`: Owner can revoke a user's access.
- `pause-contract` / `unpause-contract`: Pause/unpause contract.
- `transfer-ownership`: Transfer contract ownership.

### Read-Only Functions

- `get-content`: Get content metadata.
- `has-access`: Check if a user has access to content.
- `get-subscription`: Get subscription details.
- `get-content-rating`: Get aggregate ratings.
- `get-content-analytics`: Get analytics for content.
- `get-content-count`: Total content count.
- `get-subscription-count`: Total subscription count.
- `is-contract-paused`: Check if contract is paused.
- `get-contract-owner`: Get contract owner.
- `get-access-details`: Get access details for a user.
- `get-user-subscription`: Get user's subscription details.

---

## Error Codes

- `ERR_UNAUTHORIZED`: Unauthorized action.
- `ERR_NOT_FOUND`: Item not found.
- `ERR_ALREADY_HAS_ACCESS`: User already has access.
- `ERR_INSUFFICIENT_PAYMENT`: Not enough balance.
- `ERR_TRANSFER_FAILED`: STX transfer failed.
- `ERR_INVALID_PRICE`: Invalid price.
- `ERR_INVALID_INPUT`: Invalid input.
- `ERR_CONTRACT_PAUSED`: Contract is paused.
- `ERR_NOT_OWNER`: Not the owner.
- `ERR_INVALID_PERCENTAGE`: Invalid revenue split.
- `ERR_SUBSCRIPTION_EXPIRED`: Subscription expired.
- `ERR_DOWNLOAD_LIMIT_EXCEEDED`: Download limit exceeded.
- `ERR_INVALID_RATING`: Invalid rating.
- `ERR_ALREADY_RATED`: User already rated.

---

## Events

Events are logged using `print` for key actions:
- Content registration
- Access purchase
- Subscription purchase
- Rating added

---

## Usage

Deploy the contract on Stacks.  
Interact using Clarity calls to register content, manage access, subscriptions, revenue, and analytics.

---

## License

MIT License (see repository for details).
